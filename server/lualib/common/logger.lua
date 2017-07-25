local skynet = require "skynet"
local syslog = require "syslog"

local Logger = {}

-- local _logService = nil
-- assert(_logService ~= nil, "------ 获取 logger_server 服务失败")

Logger.assert = function(...)
    -- print("--- Logger.assert:", ...)
    assert(...)
end

Logger.debug = function(...)
    local logService = skynet.uniqueservice ("logger_server")
    skynet.call (logService, "lua", "debug", ...)  
end

Logger.noticef = function(fmt, ...)
    syslog.noticef (fmt, ...) 
end

Logger.debugf = function(fmt, ...)
    syslog.debugf(fmt, ...) 
end

Logger.warnf = function(fmt, ...)
    syslog.warningf (fmt, ...) 
end

Logger.error = function(...)
end


return Logger