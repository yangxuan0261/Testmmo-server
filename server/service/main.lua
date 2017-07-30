local skynet = require "skynet"

local config = require "config.system"
local login_config = require "config.loginserver"
local game_config = require "config.gameserver"

skynet.start(function()

    local moniter = skynet.uniqueservice ("moniter")
    skynet.call (moniter, "lua", "open")  

    local logServer = skynet.uniqueservice ("logger_server")
    skynet.call (logServer, "lua", "open")  

	skynet.newservice ("debug_console", config.debug_port)

	local database = skynet.uniqueservice ("database")
    skynet.call (database, "lua", "open")  

	local loginserver = skynet.newservice ("login_server")
	skynet.call (loginserver, "lua", "open", login_config)
    print("---------- start loginserver")	

	local gamed = skynet.newservice ("gamed", loginserver)
	skynet.call (gamed, "lua", "open", game_config)
end)
