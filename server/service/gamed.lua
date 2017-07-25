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

    local webserver = skynet.uniqueservice ("web_server")
    skynet.call (webserver, "lua", "open")
    local gdd = skynet.uniqueservice ("gdd")
    skynet.call (gdd, "lua", "open")
    local world = skynet.uniqueservice ("world")
    skynet.call (world, "lua", "open")
    local chatserver = skynet.uniqueservice ("chat_server")
    skynet.call (chatserver, "lua", "open")
    local laborserver = skynet.uniqueservice ("labor_server")
    skynet.call (laborserver, "lua", "open")
    local friendserver = skynet.uniqueservice ("friend_server")
    skynet.call (friendserver, "lua", "open")
end

function gamed.command_handler (cmd, ...)
	local CMD = {}

	function CMD.close (agent, account)
		syslog.debugf ("agent %d recycled", agent)

		online_account[account] = nil
		table.insert (pool, agent)
	end

	function CMD.kick (agent, fd)
		gameserver.kick (fd)
	end

	local f = assert (CMD[cmd])
	return f (...)
end

function gamed.auth_handler (session, token)
    -- print("---------- gamed, ", debug.traceback("", 1))
	return skynet.call (logind, "lua", "verify", session, token)	
end

function gamed.login_handler (fd, account)
	local agent = online_account[account]
	if agent then
		syslog.warningf ("multiple login detected for account %d", account)
		skynet.call (agent, "lua", "kick", account)
	end

	if #pool == 0 then
		agent = skynet.newservice ("agent", skynet.self ())
		syslog.noticef ("pool is empty, new agent(%d) created", agent)
	else
		agent = table.remove (pool, 1)
		syslog.debugf ("agent(%d) assigned, %d remain in pool", agent, #pool)
	end
	online_account[account] = agent

	skynet.call (agent, "lua", "open", fd, account)
	gameserver.forward (fd, agent)
	return agent
end

gameserver.start (gamed)
