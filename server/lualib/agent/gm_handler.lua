local skynet = require "skynet"
local sharedata = require "sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dump = require "print_r"


local REQUEST = {}
handler = handler.new (REQUEST)

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

    elseif _fn == "character_list" then

    end


    return argTab
end

local function gmExecute( gmStr )
    syslog.debugf ("--- gm command:%s", gmStr)
    local funcName, argTab = gmParser(gmStr)
    syslog.debugf ("--- gm func:%s", funcName)
    -- dump(argTab, "gmParser")

    local f = user.REQUEST[funcName] -- search request func
    assert(f, "Error: not found func:"..funcName)

    argTab = gmPackArgs(funcName, argTab)
    dump(argTab, "gmPackArgs")
    f(argTab)

    user.send_request ("tips", { content = funcName.." success!!" })
end

function REQUEST.gm (args)
    local gmStr = args.gmStr
    assert(#gmStr > 0, "Error: empty gm command")
    skynet.fork (function () gmExecute(gmStr) end)
end

return handler

