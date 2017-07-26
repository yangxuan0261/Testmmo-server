local skynet = require "skynet"
local socket = require "skynet.socket"
local syslog = require "syslog"
local srp = require "srp"
local aes = require "aes"
local uuid = require "uuid"
local dump = require "common.dump"
local ProtoProcess = require "proto.proto_process"

local traceback = debug.traceback
local assert = syslog.assert

local master
local database
local auth_timeout
local session_expire_time
local session_expire_time_in_second
local connection = {}
local saved_session = {}

local slaved = {}
local CMD = {}
local RPC = {}

local function close (fd)
	if connection[fd] then
		socket.close (fd)
		connection[fd] = nil
	end
end

function RPC.rpc_server_handshake (args)
    assert (args and args.name and args.client_pub, "invalid handshake request")
    syslog.debugf ("--- handshake, username:%s", args.name)
    local accInfo = skynet.call (database, "lua", "account", "cmd_account_load_by_name", args.name)
    assert (accInfo, string.format("load account failed, account:%s ", args.name))
    local session_key, _, pkey = srp.create_server_session_key (accInfo.verifier, args.client_pub)
    local challenge = srp.random ()
    local msg = {
        user_exists = (accInfo.id ~= nil),
        salt = accInfo.salt,
        server_pub = pkey,
        challenge = challenge,
    }
    return msg, accInfo, session_key, challenge
end

function RPC.rpc_server_auth (args, accInfo, session_key, challenge)
    assert (args and args.challenge, "invalid auth request")
    local text = aes.decrypt (args.challenge, session_key)
    assert (challenge == text, "auth challenge failed")

    local id = tonumber (accInfo.id)
    if not id then
        assert (args.password)
        id = uuid.gen ()
        local password = aes.decrypt (args.password, session_key)
        accInfo.id = skynet.call (database, "lua", "account", "cmd_account_create", id, accInfo.name, password)
        assert (accInfo.id, string.format ("create account %s/%d failed", args.name, id))
    end
    
    challenge = srp.random ()
    local session = skynet.call (master, "lua", "save_session", id, session_key, challenge)

    local msg = {
        session = session,
        expire = session_expire_time_in_second,
        challenge = challenge,
    }
    return msg
end

function RPC.rpc_server_challenge (args)
    assert (args and args.session and args.challenge)
    local retTab = skynet.call (master, "lua", "challenge", args.session, args.challenge)
    local token = retTab["token"]
    local challenge = retTab["challenge"]
    assert (token and challenge)

    local msg = {
        token = token,
        challenge = challenge,
        ip = "192.168.253.130", -- 暂时写死，for test
        port = 9555,
    }
    return msg
end

function CMD.init (m, id, conf)
    master = m
    database = skynet.uniqueservice ("database")
    auth_timeout = conf.auth_timeout * 100
    session_expire_time = conf.session_expire_time * 100
    session_expire_time_in_second = conf.session_expire_time
end

function CMD.auth (fd, addr)
	connection[fd] = addr
	skynet.timeout (auth_timeout, function ()
		if connection[fd] == addr then
			syslog.warnf ("connection %d from %s auth timeout!", fd, addr)
			close (fd)
		end
	end)

	socket.start (fd)
	socket.limit (fd, 8192)

    syslog.notice("------------------------ loginserver auth begin ------------------------")
	local proto_name, paramTab = ProtoProcess.Read(fd)
    assert (RPC[proto_name], string.format("--- dont exit protocol:%s", proto_name))

	local msg, accInfo, session_key, challenge = RPC.rpc_server_handshake(paramTab)
    ProtoProcess.Write (fd, "rpc_client_handshake", msg)

    proto_name, paramTab = ProtoProcess.Read(fd)
    assert (RPC[proto_name], string.format("--- dont exit protocol:%s", proto_name))
    msg = RPC.rpc_server_auth(paramTab, accInfo, session_key, challenge)
    ProtoProcess.Write (fd, "rpc_client_auth", msg)

    proto_name, paramTab = ProtoProcess.Read(fd)
    assert (RPC[proto_name], string.format("--- dont exit protocol:%s", proto_name))
	msg = RPC.rpc_server_challenge(paramTab)
    ProtoProcess.Write (fd, "rpc_client_challenge", msg)

    syslog.notice("------------------------ loginserver auth ok ------------------------")
	close (fd)
end

function CMD.save_session (session, account, key, challenge)
	saved_session[session] = { account = account, key = key, challenge = challenge }
	skynet.timeout (session_expire_time, function ()
		local t = saved_session[session]
		if t and t.key == key then
			saved_session[session] = nil
		end
	end)
end

function CMD.challenge (session, secret)
	local t = saved_session[session] or error ()

	local text = aes.decrypt (secret, t.key) or error ()
	assert (text == t.challenge)

	t.token = srp.random ()
	t.challenge = srp.random ()

	return { token = t.token, challenge = t.challenge }
end

function CMD.verify (session, secret)
	local t = saved_session[session] or error ()

	local text = aes.decrypt (secret, t.key) or error ()
	assert (text == t.token)
	t.token = nil

	return t.account
end

function CMD.open (conf)
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- print("--- cmd_heart_beat loginslave")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)

