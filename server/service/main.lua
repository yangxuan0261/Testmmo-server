local skynet = require "skynet"

local config = require "config.system"
local login_config = require "config.loginserver"
local game_config = require "config.gameserver"

skynet.start(function()
    skynet.uniqueservice ("moniter")

	skynet.newservice ("debug_console", config.debug_port)
	local protod = skynet.newservice ("protod")
    skynet.call (protod, "lua", "open")  
	local database = skynet.uniqueservice ("database")
    skynet.call (database, "lua", "open")  

	local loginserver = skynet.newservice ("loginserver")
	skynet.call (loginserver, "lua", "open", login_config)	

	local gamed = skynet.newservice ("gamed", loginserver)
	skynet.call (gamed, "lua", "open", game_config)
end)
