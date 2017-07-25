local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"

local FlagOffline = 0
local FlagOnline = 1

local onlineTab = {}
local table = table

local database

local CMD = {}
function CMD.open (source, conf)
    syslog.debugf("--- chat server open")
    database = skynet.uniqueservice ("database")
end

function CMD.cmd_online(source, _acc)
    local accInfo = {
        account = _acc,
        agent = source,
        online = FlagOnline,
    }
    onlineTab[_acc] = accInfo
end

function CMD.cmd_offline(source, _acc)
    local accInfo = onlineTab[_acc]
    assert(accInfo, string.format("Error, not found account:%d", _acc))

    onlineTab[_acc] = nil
end

function CMD.getOnline(source)
    return onlineTab
end

function CMD.broad(source, _acc, _msg)
    local function sendMsg( ... )
        local accInfo = onlineTab[_acc]
        assert(accInfo, string.format("Error, not found account:%d", _acc))
        for _,v in pairs(onlineTab) do
            skynet.call(v["agent"], "lua", "world_sendChat", _acc, _msg)
        end
    end
    skynet.fork(sendMsg)
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warningf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warningf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)