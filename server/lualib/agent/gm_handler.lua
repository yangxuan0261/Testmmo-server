local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"
local dbpacker = require "db.packer"

local syslog = require "syslog"
local handler = require "agent.handler"
local dump = require "common.dump"

local RPC = {}
local user
handler = handler.new (RPC)

handler:init (function (u)
	user = u
end)

local function gmExecute(gmStr)

end

function RPC.rpc_server_gm (args)

    return gmExecute(gmStr)

end

return handler

