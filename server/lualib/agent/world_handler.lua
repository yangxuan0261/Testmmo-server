local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local chatserver

handler:init (function (u)
	user = u
    database = skynet.uniqueservice ("database")
	chatserver = skynet.uniqueservice ("chat_server")
end)

local FlagOffline = 0
local FlagOnline = 1
function RPC.rpc_world_account_list ()
    local allList = skynet.call(database, "lua", "account", "loadlist")
    local onlineList = skynet.call(chatserver, "lua", "getOnline")
    if allList and #allList > 0 then
        for _,v in pairs(allList) do
            v = tonumber(v)
            if not onlineList[v] then
                local data = {
                    account = v,
                    online = FlagOffline
                }
                onlineList[v] = data
            end
        end
    end
    return onlineList
end

return handler

