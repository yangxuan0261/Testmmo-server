local skynet = require "skynet"
local syslog = require "syslog"
local srp = require "srp"
local aes = require "aes"
local uuid = require "uuid"
local dump = require "common.dump"
local ProtoProcess = require "proto.proto_process"
local netpack = require "skynet.netpack"
local dbpacker = require "db.packer"

local traceback = debug.traceback
-- local assert = syslog.assert

local master
local database
local auth_timeout
local session_expire_time
local session_expire_time_in_second

local CMD = {}
local RPC = {}
local user_fd = nil
local auth_info = nil


local function send_request (name, args)
    -- syslog.debugf("--- ProtoProcess.Write 111, name:%s", name)
    ProtoProcess.Write (user_fd, name, args)
end

local function close_fd (auth_flag, msg)
    assert(user_fd, "--- login_slave, close_fd error, user_fd is nil")
	if auth_flag then
        syslog.noticef("------------ auth success, usernme:[%s] ------------", auth_info.username)
    else
        -- todo: 认证失败，需要下行协议通知客户端
        syslog.noticef("------------ auth failed, usernem:[%s] ------------", auth_info.username)
	end

    skynet.call (master, "lua", "cmd_server_close_slave", user_fd, auth_flag)

    user_fd = nil
    auth_info = nil
end

function RPC.rpc_server_handshake (args)
    assert (args and args.name and args.client_pub, "invalid handshake request")
    syslog.debugf ("--- handshake, username:%s", args.name)
    local accInfo = skynet.call (database, "lua", "account", "cmd_account_load_by_name", args.name)
    accInfo = dbpacker.unpack (accInfo)
    syslog.debugf ("--- handshake, username 111")

    assert (accInfo, string.format("load account failed, account:%s ", args.name))
    syslog.debugf ("--- handshake, username 222")
    assert (accInfo.verifier, "rpc_server_handshake, verifier failed")
    syslog.debugf ("--- handshake, username 333")
    assert (args.client_pub, "rpc_server_handshake, client_pub failed")
    local session_key, _, pkey = srp.create_server_session_key (accInfo.verifier, args.client_pub)
    local challenge = srp.random ()

    auth_info = {
        accInfo = accInfo,
        username = args.name,
        session_key = session_key,
        challenge = challenge,
        account = nil,
        session = nil,
    }

    local msg = {
        user_exists = (accInfo.id ~= nil),
        salt = accInfo.salt,
        server_pub = pkey,
        challenge = challenge,
    }

    ProtoProcess.Write (user_fd, "rpc_client_handshake", msg)
end

function RPC.rpc_server_auth (args)
    local accInfo = auth_info.accInfo
    local session_key = auth_info.session_key
    local challenge = auth_info.challenge

    syslog.debugf ("--- rpc_server_auth, username 111")
    assert (args and args.challenge, "invalid auth request")
    syslog.debugf ("--- rpc_server_auth, username 222")
    local text = aes.decrypt (args.challenge, session_key)
    assert (challenge == text, "auth challenge failed")
    syslog.debugf ("--- rpc_server_auth, username 333")

    local account = tonumber (accInfo.id)
    if not account then
        syslog.debugf ("--- rpc_server_auth, username 334")
        assert (args.password)
        syslog.debugf ("--- rpc_server_auth, username 335")
        account = uuid.gen ()
        local password = aes.decrypt (args.password, session_key)
        syslog.debugf ("--- rpc_server_auth, username 336")
        skynet.call (database, "lua", "account", "cmd_account_create", account, accInfo.name, password)
        syslog.debugf ("--- rpc_server_auth, username 444")
        local baseInfo = {}
    end
    
    challenge = srp.random ()
    local session = skynet.call (master, "lua", "cmd_server_get_session_id")
    syslog.debugf ("--- rpc_server_auth, username 555")

    -- 保存 session
    auth_info.account = account
    auth_info.session = session
    auth_info.challenge = challenge

    local msg = {
        session = session,
        expire = session_expire_time_in_second,
        challenge = challenge,
    }
    syslog.debugf ("--- rpc_server_auth, username 666")
    ProtoProcess.Write (user_fd, "rpc_client_auth", msg)
end

local function get_challenge (secret)
    local sessioin_key = auth_info.session_key
    local challenge = auth_info.challenge
    local text = aes.decrypt (secret, sessioin_key)
        syslog.debugf ("--- rpc_server_challenge, username 223")
    assert (text == challenge, "--- error, text != challenge")
        syslog.debugf ("--- rpc_server_challenge, username 224")

    local token = srp.random ()
    return { token = token }
end

function RPC.rpc_server_challenge (args)
        syslog.debugf ("--- rpc_server_challenge, username 111")
    assert (args and args.session and args.challenge)
        syslog.debugf ("--- rpc_server_challenge, username 222")
    local retTab = get_challenge(args.challenge)
    local token = retTab["token"]
    assert (token)
        syslog.debugf ("--- rpc_server_challenge, username 333")
    
    auth_info.token = token -- 更新 token
    -- 保存相关认证数据 token
    skynet.call (master, "lua", "cmd_server_save_auth_info"
                 , auth_info.account
                 , auth_info.session
                 , auth_info.session_key
                 , auth_info.token)

    local msg = {
        token = token,
        ip = "192.168.253.130", -- 暂时写死，for test
        port = 9555,
    }
    ProtoProcess.Write (user_fd, "rpc_client_challenge", msg)
        syslog.debugf ("--- rpc_server_challenge, username 444")

    close_fd(true)
end

function CMD.cmd_slave_enter (fd, addr)
    user_fd = fd
    skynet.timeout (auth_timeout, function ()
        if auth_info ~= nil then
            syslog.warnf ("login_slave, auth timeout! fd:%d from ip:%s ", user_fd, addr)
            close_fd(false)
        end
    end)
    syslog.noticef("------ login_slave auth begin, fd:%d ip:%s ------", fd, addr)
end

function CMD.cmd_slave_leave (fd, addr)
    user_fd = nil
end

function CMD.cmd_slave_open (m, conf)
    master = m
    database = skynet.uniqueservice ("database")
    auth_timeout = conf.auth_timeout * 100
    session_expire_time = conf.session_expire_time * 100
    session_expire_time_in_second = conf.session_expire_time

    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat loginslave")
end

local function my_unpack(msg, sz)
    return netpack.tostring(msg, sz)
end

local function my_dispatch(source, session, msg, ...)
    local proto_name, args = ProtoProcess.ReadMsg(msg)

    local f = RPC[proto_name]
    if f then
        local ok, _ = xpcall (f, traceback, args)
        if not ok then
            syslog.errorf("--- login_slave, rpc exec error, name:%s", proto_name)
        end
    else
        syslog.warnf("--- login_slave, no rpc name:%s", proto_name)
    end
end

skynet.register_protocol { -- 注册与客户端交互的协议
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = my_unpack,
    dispatch = my_dispatch,
}

skynet.start (function ()
    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("login_slave, unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.errorf ("login_slave, handle message(%s) failed", command)
            -- kick_self ()
            return skynet.ret ()
        end

        syslog.debugf ("login_slave, handle message(%s) success 111", command)
        if ret ~= nil then
            skynet.retpack (ret)
        else
            skynet.ret ()
        end
        syslog.debugf ("login_slave, handle message(%s) success 222", command)
    end)
end)

