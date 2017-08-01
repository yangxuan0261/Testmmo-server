local skynet = require "skynet"
local syslog = require "syslog"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local aes = require "aes"

local CMD = setmetatable ({}, { __gc = function () netpack.clear (queue) end })

local session_id = 1
local slave_pool = {}
local config = nil
local connection = {}
local saved_session = {} -- 等待游戏服来验证的数据

local function create_slave()
    local s = skynet.newservice ("login_slave")
    skynet.call (s, "lua", "cmd_slave_open", skynet.self(), config)
    return s
end

local function init_slave_pool (num)
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

local function recycle_slave(s)
    table.insert (slave_pool, s)
end

local function start_fd(fd)
    if connection[fd] then
        socketdriver.start (fd)
    end
end

local function close_fd (fd)
    local c = connection[fd]
    if c then
        socketdriver.close (fd)
        recycle_slave(c.slave)
        connection[fd] = nil
    end
end

function CMD.open (conf)
    config = conf
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

    init_slave_pool(config.slave_num)

	local addr = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))

	syslog.noticef ("--- login_server, listen on %s:%d", addr, port)

    local socket = socketdriver.listen (addr, port)
    socketdriver.start (socket)
end

-- 账号认证成功后分配开启一次会话 session
function CMD.cmd_server_get_session_id ()
    local session = session_id
    session_id = session_id + 1
    return session
end

function CMD.cmd_server_save_auth_info (account, session, session_key, token)
    local info = {
        account = account,
        session_key = session_key,
        token = token,
    }
    saved_session[session] = info
end

function CMD.cmd_server_verify (session, token)
    if session == nil then return nil end

    local account = nil
    local info = saved_session[session]
    if info then
        local text = aes.decrypt (token, info.session_key) or error ()
        print("--- text", text)
        print("--- info.token", info.token)
        if text == info.token then
            account = info.account
        else
            syslog.errorf("--- login_server, verify failed, text ~= info.token")
        end
        saved_session[session] = nil
    end

    if account ~= nil then
        syslog.debugf("--- login_server, verify from gamed is success, account:%d", account)
    end
	return account
end

function CMD.cmd_server_close_slave (fd, auth_flag)
    close_fd(fd)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat loginslave")
end

local MSG = {}
function MSG.open (fd, addr)
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
    skynet.call (s, "lua", "cmd_slave_enter", fd, addr)

    start_fd(fd)
end

function MSG.close (fd)
    syslog.debugf("--- login_server, socket 已断开，MSG.close")
    close_fd (fd)
end

function MSG.error (fd, msg)
    syslog.debugf("--- login_server, socket 已断开，MSG.error, msg:%s", msg)
    close_fd (fd)
end

local function dispatch_msg (fd, msg, sz)
    local c = connection[fd]
    local slave = c and c.slave
    if slave then -- 如果有对应的slave连接，则转发给对应的slave处理
        skynet.redirect (slave, 0, "client", 0, msg, sz)
    else -- 否则让继承这个gateserver的服务中的handler.message处理
        -- handler.message (fd, msg, sz)
        syslog.errorf("--- login_server, dispatch_msg, not fd found:%d", fd)
    end
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
        return netpack.filter (queue, msg, sz) 
    end,
    dispatch = function (_, _, q, type, ...)
        queue = q
        if type then
            return MSG[type] (...) 
        end
    end,
}

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
}

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
