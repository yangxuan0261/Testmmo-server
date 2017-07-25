local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local dump = require "common.dump"


local REQUEST = {}
local CMD = {}
handler = handler.new (REQUEST, nil, CMD)

local user
local database
local laborserver

handler:init (function (u)
	user = u
	database = skynet.uniqueservice ("database")
    laborserver = skynet.uniqueservice ("laborserver")
end)

function REQUEST.labor_create (args)
    assert(args.name, "Error: REQUEST.labor_create")
    local laborData = skynet.call (laborserver, "lua", "create", user.account, args.name)
    if laborData then
        user.info.laborId = laborData["id"]
        user.send_request ("tips", { content = string.format("create 【%s】 success!!", laborData["name"]) })
    end
end

function REQUEST.labor_list (args)
    local laborTab = skynet.call (laborserver, "lua", "list")
    -- dump(laborTab, "labor_list")
    return laborTab
end

function REQUEST.labor_members (args)
    assert(args.id)
    local laborTab = skynet.call (laborserver, "lua", "get_members", args.id)
    for k,v in pairs(laborTab) do
        print(k,v)
    end
end

function REQUEST.labor_join (args)
    assert(args.id, "Error: REQUEST.labor_join")
    if user.info.laborId then
        user.send_request ("tips", { content = "please leave current labor" })
    else
        user.info.laborId = args.id
        local json = dbpacker.pack(user.info)
        skynet.call (database, "lua", "account", "saveInfo", user.account, json)

        local laborName = skynet.call (laborserver, "lua", "join", user.account, args.id)
        if laborName then
            user.send_request ("tips", { content = string.format("join 【%s】 success!!", laborName) })
        end
    end
end

function REQUEST.labor_leave (args)
    assert(user.info.laborId, "Error: REQUEST.labor_leave")
    local laborId = user.info.laborId
    user.info.laborId = nil
    local json = dbpacker.pack(user.info)
    skynet.call (database, "lua", "account", "saveInfo", user.account, json)
    local laborName = skynet.call (laborserver, "lua", "leave", user.account, laborId)
    if laborName then
        user.send_request ("tips", { content = string.format("leave 【%s】 success!!", laborName) })
    end
end

function REQUEST.labor_chat (args)
    assert(args.msg)
    local laborId = user.info.laborId
    assert(laborId, "Error: dont join a labor")

    skynet.fork(function()
        skynet.call (laborserver, "lua", "broad", laborId, user.account, args.msg)
    end)
end

function CMD.labor_sendChat( _account, _msg )
    -- user.send_request ("labor_send", { msg = _msg }) -- protocol
    local info = skynet.call (database, "lua", "account", "loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end

    local msg = {
        id = info.nickName,
        msg = _msg,
    }

    user.send_request ("user_chat", { flag = user.FlagDef.Chat_Labor, data = dbpacker.pack(msg) })

    -- user.send_request ("tips", { content = string.format("【%s】 say:%s", info.nickName, _msg) })
end

return handler

