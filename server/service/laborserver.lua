require "functions"
local skynet = require "skynet"
local syslog = require "syslog"
local uuid = require "uuid"
-- local dump = require "print_r"
local dbpacker = require "db.packer"

-- local gamed = tonumber (...)

local agentTab = {}
local accountTab = {}

local friendHandler
local laborHandler
local worldHandler

local laborTab = {}

local database

local CMD = {}
function CMD.open (source, conf)
    syslog.debugf("--- labor server open")

    database = skynet.uniqueservice ("database")
    local dataTab = skynet.call (database, "lua", "labor", "list")
    if not dataTab then
        dataTab = {}
    end

    for k,v in pairs(dataTab) do
        v = dbpacker.unpack(v) -- decode json
        laborTab[v.id] = v
    end
    dump(laborTab, "all labor")
end

function CMD.create(source, _account, _laborName)
    local account = {}
    account["account"] = _account -- acc
    account["online"] = 1        -- online
    account["agent"] = source

    local laborInfo = {
            id = uuid.gen(),
            ctor = _account,
            name = _laborName,
            members = {}
        }
    laborInfo["members"][_account] = account -- insert creater
    dump(laborInfo, "labor_create")

    local json = dbpacker.pack (laborInfo)
    local id = skynet.call (database, "lua", "labor", "save", laborInfo.id, json)
    syslog.debugf("--- create labor success, id:%d", id)

    laborTab[id] = laborInfo
    syslog.debugf("--- create labor success, name:%s", laborInfo.name)
    return { id = id, name = laborInfo.name }
end

function CMD.join(source, _account, _laborId)
    local labor = laborTab[_laborId]
    assert(labor, "Error, join labor fail")

    local account = {}
    account["account"] = _account
    account["online"] = 1
    account["agent"] = source
    labor.members[_account] = account

    local json = dbpacker.pack (labor)
    local id = skynet.call (database, "lua", "labor", "save", _laborId, json)

    return labor.name
end

function CMD.leave(source, _account, _laborId)
    local labor = laborTab[_laborId]
    assert(labor, "Error, leave labor fail")
    labor.members[_account] = nil
    local json = dbpacker.pack (labor)
    local id = skynet.call (database, "lua", "labor", "save", _laborId, json)
    return labor.name
end

function CMD.online(source, _account, _laborId)
    if not _laborId then
        return
    end

    local labor = laborTab[_laborId]
    assert(labor, "Error, labor online fail")
    labor.members[_account]["online"] = 1
    labor.members[_account]["agent"] = source
end

function CMD.offline(source, _account, _laborId)
    if not _laborId then
        return
    end

    local labor = laborTab[_laborId]
    assert(labor, "Error, labor offline fail")
    labor.members[_account]["online"] = 0
    labor.members[_account]["agent"] = nil
end

function CMD.list (source, id)
    return laborTab
end

function CMD.get_members (source, id)
    local labor = laborTab[id]
    assert(labor, "Error, not found labor, id:"..id)
    return labor.members
end

function CMD.broad (source, id, _account, _msg)
    local function sendMsg( ... )
        local members = CMD.get_members(nil, id)
        for _,v in pairs(members) do
            if v["online"] then
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
            kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)


