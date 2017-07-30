local skynet = require "skynet"
-- local socket = require "skynet.socket"
local netpack = require "skynet.netpack"
local syslog = require "syslog"
local config = require "config.system"


local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local socket
local socketdriver = require "skynet.socketdriver"

    local MSG = {}


local CMD = {}

local queue
local CMD = setmetatable ({}, { __gc = function () netpack.clear (queue) end })


function CMD.open (conf)
    syslog.debug("--- login_sever, CMD.open")
    print("--- login_sever, CMD.open")

    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

	for i = 1, conf.slave do
		local s = skynet.newservice ("login_slave")
        skynet.call (s, "lua", "init", skynet.self (), i, conf)
		skynet.call (s, "lua", "open")
		table.insert (slave, s)
	end
	nslave = #slave

	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	-- local sock = socket.listen (host, port)

    socket = socketdriver.listen (host, port)
    socketdriver.start (socket)
    print ("listen on %s:%d", host, port)

	-- local balance = 1
	-- socket.start (sock, function (fd, addr)
	-- 	local s = slave[balance]
	-- 	balance = balance + 1
	-- 	if balance > nslave then balance = 1 end
 --            syslog.debugf ("---@ loginslave, connection %d from %s, balance:%d", fd, addr, balance)
	-- 	skynet.call (s, "lua", "cmd_slave_auth", fd, addr)
	-- end)
end

function MSG.open (fd, addr)
    syslog.debugf("--- login_sever, MSG.open, fd:%d", fd)

end


function CMD.cmd_server_save_session (account, key, challenge)
	local session = session_id
	session_id = session_id + 1

	s = slave[(session % nslave) + 1]
	skynet.call (s, "lua", "cmd_slave_save_session", session, account, key, challenge)
	return session
end

function CMD.cmd_server_challenge (session, challenge)
	s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "cmd_slave_challenge", session, challenge)
end

function CMD.cmd_server_verify (session, token)
	local s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "cmd_slave_verify", session, token)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat loginslave")
end

function MSG.close (fd)
    syslog.debugf("--------------- login_sever, socket 已断开，MSG.close")
end

function MSG.error (fd, msg)
    syslog.debugf("--------------- login_sever, socket 已断开，MSG.error")
end

local function dispatch_msg (fd, msg, sz)
    syslog.debugf("--- login_sever, dispatch_msg, fd:%d, sz:%d", fd, sz)
    -- local c = connection[fd]
    -- local agent = c.agent
    -- if agent then -- 如果有对应的agent连接，则转发给对应的agent处理
    --     skynet.redirect (agent, 0, "client", 0, msg, sz)
    -- else -- 否则让继承这个gateserver的服务中的handler.message处理
    --     handler.message (fd, msg, sz)
    -- end
end

MSG.data = dispatch_msg

local function dispatch_queue ()
    local fd, msg, sz = netpack.pop (queue)
    if fd then
        skynet.fork (dispatch_queue)
        dispatch_msg (fd, msg, sz)

        for fd, msg, sz in netpack.pop, queue do
            dispatch_msg (fd, msg, sz)
        end
    end
end

MSG.more = dispatch_queue

skynet.register_protocol {
    name = "socket",
    id = skynet.PTYPE_SOCKET,
    unpack = function (msg, sz)
        print("--- login_sever, unpack, sz:%d", sz)
        return netpack.filter (queue, msg, sz) 
    end,
    dispatch = function (a, b, q, type, ...)
        print("--- login_sever, dispatch, type:%s 111", a, b, q, type)
        queue = q
        if type then
            print("--- login_sever, dispatch, type:%s", type)
            return MSG[type] (...) 
        end
    end,
}

local traceback = debug.traceback
    skynet.start(function()
        skynet.dispatch("lua", function (_, address, cmd, ...)
            local f = CMD[cmd]
            if f then
                skynet.ret(skynet.pack(f(...)))
            else
                skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
            end
        end)
    end)
