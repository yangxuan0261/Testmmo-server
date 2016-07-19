local skynet = require "skynet"
local sharedata = require "sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local REQUEST = {}
local CMD = {}
handler = handler.new (REQUEST, nil, CMD)

local user
local database
local chatserver

handler:init (function (u)
	user = u
    database = skynet.uniqueservice ("database")
	chatserver = skynet.uniqueservice ("chatserver")
end)

function REQUEST.world_chat (args)
    assert(args.msg)
    skynet.call(chatserver, "lua", "broad", user.account, args.msg)
end

local FlagOnline = 1
function REQUEST.world_accountList ()
    local ret = {}
    local allList = skynet.call(database, "lua", "account", "loadlist")
    local onlineList = skynet.call(chatserver, "lua", "getOnline")
    if allList and #allList > 0 then
        for _,v in pairs(allList) do
            if not onlineList[v] then
                local data = {
                    account = v,
                    online = FlagOnline
                }
                onlineList[v] = data
            end
        end
    end
    dump(onlineList, "--- world_accountList")
    return ret
end

function CMD.world_sendChat( _account, _msg )
    -- user.send_request ("labor_send", { msg = _msg }) -- protocol
    local info = skynet.call (database, "lua", "account", "loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 say:%s", info.nickName, _msg) })
end

return handler

