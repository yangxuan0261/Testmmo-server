local skynet = require "skynet"
-- local sharedata = require "sharedata"
local sharedata = require "skynet.sharedata"
local dbpacker = require "db.packer"

local syslog = require "syslog"
local handler = require "agent.handler"
local dump = require "common.dump"


local RPC = {}
handler = handler.new (RPC)

local user
local database
local gdd

handler:init (function (u)
	user = u
	database = skynet.uniqueservice ("database")
end)

local function gmParser( gmStr )
    local rets = string.gmatch(gmStr, "%S+")
    local argTab = {}
    for i in (rets) do
        table.insert(argTab, i)
    end

    local func = argTab[1]
    table.remove(argTab, 1)
    return func, argTab
end

local function gmPackArgs( _fn, _args )
    local argTab = {}
    local retFunc = ""
    if _fn == "character_delete" then
        argTab = { id = tonumber(_args[1]) }

    elseif _fn == "character_create" then
        argTab = {
            character = {
                name = _args[1],
                race = _args[2],
                class = _args[3]
            }
        }

    elseif _fn == "character_list" then

    elseif _fn == "labor_create" then
        argTab = {
            name = _args[1],
        }

    elseif _fn == "labor_list" then

    elseif _fn == "labor_chat" then
        argTab = {
            msg = _args[1],
        }

    elseif _fn == "labor_join" then
        argTab = {
            id = tonumber(_args[1]),
        }

    elseif _fn == "world_accountList" then
        retFunc = "helloFunc"
    end

    return argTab, retFunc
end

local function gmExecute(gmStr)
    local funcName, argTab, retFunc = gmParser(gmStr)
    syslog.debugf ("--- gm func:%s", funcName)
    -- dump(argTab, "gmParser")

    local f = user.RPC[funcName] -- search request func
    assert(f, "Error: not found func:"..funcName)

    argTab, retFunc = gmPackArgs(funcName, argTab)
    local ret = f(argTab)
    -- dump(ret, "--- ret")

    local b = retFunc and ret and type(ret) == "table"
    if not b then
        syslog.debugf("dont neet return, request:%s", funcName)
        return
    end

    return { func = retFunc, data = dbpacker.pack(ret)}
        -- user.send_request (, { content = funcName.." success!!" })
end

function RPC.gm (args)
    local gmStr = args.data
    assert(gmStr and #gmStr > 0, "Error: empty gm")
    return gmExecute(gmStr)
    -- skynet.fork (function () gmExecute(gmStr) end)
end

return handler

