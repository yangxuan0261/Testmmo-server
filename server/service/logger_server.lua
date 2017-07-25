local skynet = require "skynet"
local syslog = require "syslog"

local _logId = 0

local CMD = {}
function CMD.open()
    
end

function CMD.debug(...)
    print("--- Logger.debug:", ...)
end

function CMD.warn()
    
end

function CMD.error()
    
end

function CMD.heart_beat ()
    -- print("--- heart_beat loginslave")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warningf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warningf ("handle message(%s) failed : %s", command, ret)
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)
