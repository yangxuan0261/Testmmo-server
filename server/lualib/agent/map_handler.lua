local skynet = require "skynet"

local syslog = require "syslog"
local handler = require "agent.handler"


local RPC = {}
local REQUEST = {}
local user
handler = handler.new (RPC)

handler:init (function (u)
	user = u
end)

function RPC.map_ready ()
	local ok = skynet.call (user.map, "lua", "character_ready", user.character.movement.pos) or error ()
end

return handler
