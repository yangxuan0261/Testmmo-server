local skynet = require "skynet"
local syslog = require "syslog"

local protoloader = require "protoloader"

local CMD = {}
function CMD.open()
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", "protod")
end

function CMD.heart_beat ()
    -- print("--- heart_beat protod")
end

local traceback = debug.traceback
skynet.start (function ()
	protoloader.init ()
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
