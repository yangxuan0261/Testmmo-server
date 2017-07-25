local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local REQUEST = {}
local CMD = {}
handler = handler.new (REQUEST, nil, CMD)

local user
local database
local friendserver

handler:init (function (u)
	user = u
    database = skynet.uniqueservice ("database")
	friendserver = skynet.uniqueservice ("friend_server")
end)

function REQUEST.friend_addApply (args)
    assert(args.account)
    skynet.call(friendserver, "lua", "addApply", user.account, args.account)
end

function REQUEST.friend_addConfirm (args)
    assert(args.account and args.flag)
    skynet.call(friendserver, "lua", "addConfirm", user.account, args.account, args.flag)
end

function REQUEST.friend_list (args)
    local friends = skynet.call(friendserver, "lua", "getFrends", user.account)
    dump(friends, "--- friend_list")
    return friends
end

function CMD.friend_sendChat( _account, _msg )
    -- user.send_request ("labor_send", { msg = _msg }) -- protocol
    local info = skynet.call (database, "lua", "account", "loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 say:%s", info.nickName, _msg) })
end

function CMD.friend_onlineNty( _account )
    local info = skynet.call (database, "lua", "account", "loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 online", info.nickName) })
end

function CMD.friend_add( _account, _flag )
    local info = skynet.call (database, "lua", "account", "loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 add applying:%d", info.nickName, _flag) })
end

return handler

