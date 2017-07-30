local skynet = require "skynet"
local socket = require "skynet.socket"

local syslog = require "syslog"
local config = require "config.system"


local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local slave_pool = {}
local config = nil
local connection = {}

local function create_slave()
    local s = skynet.newservice ("login_slave")
    skynet.call (s, "lua", "cmd_slave_init", skynet.self(), config)
    skynet.call (s, "lua", "cmd_slave_open")
    return s
end

local function init_slave ()
    local num = config.slaveName or 10
    for i = 1,  num do
        local s = create_slave()
        table.insert (slave_pool, s)
    end
end

local function get_slave()
    local s = nil
    if #slave_pool == 0 then
        s = create_slave()
    else
        s = table.remove (slave_pool, 1)
    end
    syslog.noticef("%d remain in slave_pool", #slave_pool)
    return s
end

local function check_connection(fd)

end

local function close_fd (fd)
    if connection[fd] then
        socket.close (fd)
        connection[fd] = nil
    end
end

local CMD = {}

function CMD.open (conf)
    config = conf
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

    init_slave(conf.)


	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	local sock = socket.listen (host, port)

    nslave = #slave
	syslog.noticef ("listen on %s:%d", host, port)

	socket.start (sock, function (fd, addr)
        local c = connection[fd]
        if c then
            close_fd(fd)
        end

        local s = get_slave()
        c = {
            fd = fd,
            addr = addr,
            slave = s,
        }
        connection[fd] = c
        syslog.debugf ("--- login_server, client connection, fu:%d, from ip:%s", fd, addr)
		skynet.call (s, "lua", "cmd_slave_auth", fd, addr)
	end)
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
