local skynet = require "skynet"
local syslog = require "syslog"
local uuid = require "uuid"
local dump = require "common.dump"
local dbpacker = require "db.packer"

local FlagOffline = 0
local FlagOnline = 1

-- local gamed = tonumber (...)

local laborTab = {}

local database

local CMD = {}
function CMD.open (source, conf)
    syslog.debugf("--- %s open", SERVICE_NAME)

    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

    database = skynet.uniqueservice ("database")
    local dataTab = skynet.call (database, "lua", "labor", "loadlist")

    for _,v in pairs(dataTab) do
        v = skynet.call (database, "lua", "labor", "loadInfo", v)
        v = dbpacker.unpack(v) -- decode json
        laborTab[v.id] = v
    end
    dump(laborTab, "all labor")
end

function CMD.heart_beat ()
    -- print("--- heart_beat laborserver")
end

function CMD.create(source, _account, _laborName)
    local account = {
        account = _account,
        online = FlagOnline,
        agent = source,
        }

    local laborInfo = {
            id = uuid.gen(),
            ctor = _account,
            name = _laborName,
            members = {}
        }
    laborInfo["members"][_account] = account -- insert creater

    dump(laborInfo, "labor_create")

    local json = dbpacker.pack (laborInfo)
    local id = skynet.call (database, "lua", "labor", "saveInfo", laborInfo.id, json)
    syslog.debugf("--- create labor success, id:%d", id)

    laborTab[id] = laborInfo
    syslog.debugf("--- create labor success, name:%s", laborInfo.name)
    return { id = id, name = laborInfo.name }
end

function CMD.join(source, _account, _laborId)
    local labor = laborTab[_laborId]
    assert(labor, "Error, join labor fail")

    local account = {
        account = _account,
        online = FlagOnline,
        agent = source,
        }
    labor["members"][_account] = account

    local json = dbpacker.pack (labor)
    local id = skynet.call (database, "lua", "labor", "saveInfo", _laborId, json)

    return labor.name
end

function CMD.leave(source, _account, _laborId)
    local labor = laborTab[_laborId]
    assert(labor, "Error, leave labor fail")
    labor["members"][_account] = nil
    local json = dbpacker.pack (labor)
    local id = skynet.call (database, "lua", "labor", "saveInfo", _laborId, json)
    return labor.name
end

function CMD.cmd_online(source, _account, _laborId)
    if not _laborId then
        return
    end

    local labor = laborTab[_laborId]
    assert(labor, "Error, labor online fail")
    labor["members"][_account]["online"] = FlagOnline
    labor["members"][_account]["agent"] = source
end

function CMD.cmd_offline(source, _account, _laborId)
    if not _laborId then
        return
    end

    local labor = laborTab[_laborId]
    assert(labor, "Error, labor offline fail")
    labor["members"][_account]["online"] = FlagOffline
    labor["members"][_account]["agent"] = nil
end

function CMD.list (source, id)
    return laborTab
end

function CMD.get_members (source, id)
    local labor = laborTab[id]
    assert(labor, string.format("Error, not found labor, id:%d", id))
    return labor["members"]
end

function CMD.broad (source, id, _account, _msg)
    local function sendMsg( ... )
        local members = CMD.get_members(nil, id)
        for _,v in pairs(members) do
            if v["online"] == FlagOnline then
                skynet.call (v["agent"], "lua", "labor_sendChat", _account, _msg)
            end
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
