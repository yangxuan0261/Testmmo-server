local skynet = require "skynet"
local socket = require "socket"

local syslog = require "syslog"
local config = require "config.system"


local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local CMD = {}

function CMD.open (conf)
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

	for i = 1, conf.slave do
		local s = skynet.newservice ("loginslave")
        skynet.call (s, "lua", "init", skynet.self (), i, conf)
		skynet.call (s, "lua", "open")
		table.insert (slave, s)
	end
	nslave = #slave

	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	local sock = socket.listen (host, port)

	syslog.noticef ("listen on %s:%d", host, port)

	local balance = 1
	socket.start (sock, function (fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > nslave then balance = 1 end
            syslog.debugf ("---@ loginslave, connection %d from %s, balance:%d", fd, addr, balance)
		skynet.call (s, "lua", "auth", fd, addr)
	end)
end

function CMD.save_session (account, key, challenge)
	session = session_id
	session_id = session_id + 1

	s = slave[(session % nslave) + 1]
	skynet.call (s, "lua", "save_session", session, account, key, challenge)
	return session
end

function CMD.challenge (session, challenge)
	s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "challenge", session, challenge)
end

function CMD.verify (session, token)
	local s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "verify", session, token)
end

function CMD.heart_beat ()
    -- print("--- heart_beat loginslave")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warningf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warningf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)
