local skynet = require "skynet"
local syslog = require "syslog"

-- 日志处理服务，可以io到本地文件或者数据库中

local _logId = 0

local CMD = {}
function CMD.open()
    
end

function CMD.debug( serviceName, ...)
    _logId = _logId + 1
    -- print("--- Logger.debug:", _logId, serviceName, ...)
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
