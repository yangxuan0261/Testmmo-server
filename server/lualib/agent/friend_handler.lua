local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, nil, CMD)

local user
local database
local friendserver

handler:init (function (u)
	user = u
    database = skynet.uniqueservice ("database")
	friendserver = skynet.uniqueservice ("friend_server")
end)

function RPC.rpc_server_friend_add_apply (args)
    assert(args.account)
    skynet.call(friendserver, "lua", "cmd_add_apply", user.account, args.account)
end

function RPC.rpc_server_friend_add_confirm (args)
    assert(args.account and args.flag)
    skynet.call(friendserver, "lua", "addConfirm", user.account, args.account, args.flag)
end

function RPC.rpc_server_friend_list (args)
    local friends = skynet.call(friendserver, "lua", "getFrends", user.account)
    dump(friends, "--- friend_list")
    return friends
end

function CMD.cmd_friend_send_msg( _account, _msg )
    -- user.send_request ("labor_send", { msg = _msg }) -- protocol
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 say:%s", info.nickName, _msg) })
end

function CMD.cmd_friend_online_notify( _account )
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 online", info.nickName) })
end

function CMD.cmd_friend_add( _account, _flag )
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 add applying:%d", info.nickName, _flag) })
end

return handler

