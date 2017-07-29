local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"

local FlagOffline = 0
local FlagOnline = 1

local onlineTab = {}
local table = table
local assert = syslog.assert

local database

local CMD = {}
function CMD.cmd_open (source, conf)
    syslog.noticef("--- 聊天服 open")
    database = skynet.uniqueservice ("database")
end

function CMD.cmd_online(source, account)
    local accInfo = {
        account = account,
        agent = source,
        online = FlagOnline,
    }
    onlineTab[account] = accInfo
    syslog.noticef("聊天服，用户上线，account:%d", account)
end

function CMD.cmd_offline(source, account)
    local accInfo = onlineTab[account]
    assert(accInfo, string.format("Error, not found account:%d", account))

    onlineTab[account] = nil
    syslog.noticef("聊天服，用户下线，account:%d", account)
end

function CMD.getOnline(source)
    return onlineTab
end

function CMD.cmd_chat_world_broadcast(source, acc, msg)
    local account = acc
        print("------------------- account, ", type(account), account)
    -- local function sendMsg( ... )
        print("------------------- account, ", type(account), account)
        local accInfo = onlineTab[account]
        assert(accInfo, string.format("Error, not found account:%d", account))
        for _,v in pairs(onlineTab) do
            skynet.call(v["agent"], "lua", "cmd_chat_world", account, msg)
        end
    -- end
    -- skynet.fork(sendMsg)
    -- sendMsg()
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)