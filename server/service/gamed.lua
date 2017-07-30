local skynet = require "skynet"

local gameserver = require "gameserver.gameserver"
local syslog = require "syslog"

local table = table
local logind = tonumber (...)

local gamed = {}

local pending_agent = {}
local pool = {}

local online_account = {}

function gamed.open (config)
	syslog.notice ("gamed opened")

	local self = skynet.self ()
	local n = config.pool or 0
	for i = 1, n do
		table.insert (pool, skynet.newservice ("agent", self))
	end

    -- local webserver = skynet.uniqueservice ("web_server")
    -- skynet.call (webserver, "lua", "open")
    local gdd = skynet.uniqueservice ("gdd")
    skynet.call (gdd, "lua", "open")
    -- local world = skynet.uniqueservice ("world")
    -- skynet.call (world, "lua", "open")
    local chatserver = skynet.uniqueservice ("chat_server")
    skynet.call (chatserver, "lua", "cmd_open")
    local laborserver = skynet.uniqueservice ("labor_server")
    skynet.call (laborserver, "lua", "open")
    local friendserver = skynet.uniqueservice ("friend_server")
    skynet.call (friendserver, "lua", "open")
end

local function forward_agent(fd, account, session)
    local agent = nil
    if #pool == 0 then
        agent = skynet.newservice ("agent", skynet.self ())
        syslog.noticef ("pool is empty, new agent(%d) created", agent)
    else
        agent = table.remove (pool, 1)
        syslog.debugf ("agent(%d) assigned, %d remain in pool", agent, #pool)
    end

    online_account[account] = { 
            agent = agent,
            isKick = false, -- 成功分配 agent 后被踢标记置为 false
            fd = nil,
            session = nil,
        }

    skynet.call (agent, "lua", "cmd_agent_open", fd, account, session)
    gameserver.deal_pending_msg (fd, agent)
    gameserver.forward (fd, agent) -- 在 gateserver 中 dispatch msg 是，直接重定向到对应的 agent
end

function gamed.command_handler (cmd, ...)
	local CMD = {}

	function CMD.cmd_gamed_close (agent, account, session)
        local info = online_account[account]
        if info ~= nil then
            if info.isKick then -- socket关闭后再处理再次登陆后分配agent
                syslog.warnf ("挤号重登处理, account:%d", account)
                forward_agent(info.fd, account)
            else
                online_account[account] = nil
            end 
        end
        syslog.debugf ("agent %d recycled", agent)
		table.insert (pool, agent)
	end

	function CMD.cmd_gamed_kick (agent, fd)
		gameserver.kick (fd)
	end

	local f = assert (CMD[cmd])
	return f (...)
end

function gamed.auth_handler (session, token)
    -- syslog.debugf ("---------- gamed, %s", debug.traceback("", 1))
	return skynet.call (logind, "lua", "cmd_server_verify", session, token)	
end

function gamed.login_handler (fd, account, session)
	local info = online_account[account]
    local agent = info and info.agent

    -- 多次登陆，类似挤号，保存相关信息
    -- 1. 账号在其他地方登陆, 
	if agent then 
		syslog.warnf ("multiple login detected for account %d", account)
        skynet.call (agent, "lua", "cmd_agent_other_login") -- 
		skynet.call (agent, "lua", "cmd_agent_kick", account) -- 用户重登，踢出之前的用户，然后在之前用户 sock 关闭后，再处理登陆
        info.isKick = true
        info.fd = fd
        info.session = session
    else
        forward_agent(fd, account, session)
	end
end

gameserver.start (gamed)
