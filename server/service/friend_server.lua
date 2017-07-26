local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"

local FlagNone = 0
local FlagAccept = 1
local FlagBeAccept = 2
local FlagReject = 3
local FlagBeReject = 4
local FlagApplying = 5
local FlagBeApply = 6
local FlagOK = 7

local FlagOffline = 0
local FlagOnline = 1

local table = table

local friendTab = {}

local database

local function isOnline(account)
    local friInfo = friendTab[account]
    if friInfo and friInfo["online"] == FlagOffline then
        return true, friInfo["agent"]
    end
end

local function onlineNotify(account, _func, ...)
    local ok, agent = isOnline(account)
    if ok then
        skynet.call(agent, "lua", _func, ...)
    end
end

local function saveAddInfo(_srcAcc, _dstAcc, _flag)
    local addInfo = {
        account = _srcAcc,
        flag = _flag,
    }
    local json = dbpacker.pack(addInfo)
    skynet.call(database, "lua", "friend", "saveFriend", _srcAcc, _dstAcc, json)
end

local function loadAddInfo(_srcAcc, _dstAcc)
    local json = skynet.call(database, "lua", "friend", "loadFreind", _srcAcc, _dstAcc)
    if json then
        return true, dbpacker.unpack(json)
    end
end

local CMD = {}
function CMD.cmd_online(source, account)
    local tmp = {}
    local friends = skynet.call(database, "lua", "friend", "loadFreindList", account)
    dump(friends, "--- friends")
    if friends then
        for _,v in pairs(friends) do
            v = dbpacker.unpack(v)
            tmp[v.account] = v
            onlineNotify(v.account, "friend_onlineNty", account, FlagOnline)
        end
    end

    local friInfo = {
        account = account,
        agent = source,
        online = FlagOnline,
        friends = tmp,
    }
    friendTab[account] = friInfo
end

function CMD.cmd_offline(source, account)
    local friInfo = friendTab[account]
    assert(friInfo, string.format("Error, not found account:%d", account))
    friInfo["agent"] = nil
    friInfo["online"] = FlagOffline

    local friends = friInfo["friends"]
    for _,v in pairs(friends) do
        onlineNotify(v.account, "friend_onlineNty", account, FlagOffline)
    end
end

function CMD.cmd_add_apply(source, _srcAcc, _dstAcc)
    local friInfo = friendTab[_srcAcc]
    assert(friInfo, string.format("Error, not found account:%d", _srcAcc))

    onlineNotify(_dstAcc, "friend_add", _srcAcc, FlagBeApply)

    -- save flag
    saveAddInfo(_srcAcc, _dstAcc, FlagApplying) -- add
    saveAddInfo(_dstAcc, _srcAcc, FlagBeApply) -- be add
end

function CMD.addConfirm(source, _srcAcc, _dstAcc, _flag)
    local friInfo = friendTab[_srcAcc]
    assert(friInfo, string.format("Error, not found account:%d", _srcAcc))

    local ok , addInfo = loadAddInfo(_srcAcc, _dstAcc)
    assert(ok)

    local b = addInfo["flag"] == FlagBeApply -- only beApply can go
    assert(b, string.format("Error, addInfo flag:%d", addInfo["flag"]))

    -- save flag
    if _flag == FlagAccept then
        saveAddInfo(_srcAcc, _dstAcc, FlagOK) -- add
        saveAddInfo(_dstAcc, _srcAcc, FlagOK) -- be add
    else
        saveAddInfo(_srcAcc, _dstAcc, FlagReject) -- add
        saveAddInfo(_dstAcc, _srcAcc, FlagBeReject) -- be add
    end
end

function CMD.del(source, _srcAcc, _dstAcc)
    local friInfo = friendTab[_srcAcc]
    assert(friInfo, string.format("Error, not found account:%d", _srcAcc))

    local dstInfo = friInfo["friends"][_dstAcc]
    assert(dstInfo, string.format("Error, not found account:%d", _dstAcc))

    local b1 = skynet.call(database, "lua", "friend", "delFreind", _srcAcc, _dstAcc)
    local b2 = skynet.call(database, "lua", "friend", "delFreind", _srcAcc, _dstAcc)
    assert(b1 and b2, "Error, freind del")
end

function CMD.getFrends(source, account)
    local friInfo = friendTab[_srcAcc]
    assert(friInfo, string.format("Error, not found account:%d", account))
    local ret = {}
    local friends = friInfo["friends"]
    for _,v in pairs(friends) do
        local ok, _ = isOnline(v.account)
        local flag = ok and FlagOnline or FlagOffline
        table.insert(ret, { account = v.account, online = flag})
    end
    return ret
end

function CMD.broad(source, _srcAcc, _dstAcc, _msg)
    local function sendMsg( ... )
        onlineNotify(_dstAcc, "friend_sendChat", _srcAcc, _msg)
    end
    skynet.fork(sendMsg)
end

function CMD.open (source, conf)
    syslog.debugf("--- friend server open")
    database = skynet.uniqueservice ("database")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- print("--- cmd_heart_beat friendserver")
end

local traceback = debug.traceback
skynet.start (function ()
    -- skynet.timeout (800, function() skynet.exit() end) -- for test moniter

    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)
