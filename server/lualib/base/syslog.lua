local skynet = require "skynet"
local string = string
local assert = assert
local traceback = debug.traceback

local syslog = {
	prefix = {
        string.format("【D|%15.15s】", SERVICE_NAME),
        string.format("【I|%15.15s】", SERVICE_NAME),
        string.format("【N|%15.15s】", SERVICE_NAME),
        string.format("【W|%15.15s】", SERVICE_NAME),
        string.format("【E|%15.15s】", SERVICE_NAME),
	},
}

local level
function syslog.level (lv)
	level = lv
end

local function write (priority, fmt, ...)
	if priority >= level then
		skynet.error (syslog.prefix[priority] .. fmt, ...)
	end
end

local function writef (priority, fmt, ...)
	if priority >= level then
        local args = {...}
        if #args > 0 then
            skynet.error (syslog.prefix[priority] .. string.format (fmt, ...))
        else
            write(priority, fmt, ...)
        end
	end
end

function syslog.debug (...)
	write (1, ...)
    local logService = skynet.uniqueservice ("logger_server")
    skynet.call (logService, "lua", "debug", SERVICE_NAME, ...)
end

function syslog.debugf (...)
	writef (1, ...)
    local logService = skynet.uniqueservice ("logger_server")
    skynet.call (logService, "lua", "debug", SERVICE_NAME, ...)  
end

function syslog.info (...)
	write (2, ...)
end

function syslog.infof (...)
	writef (2, ...)
end

function syslog.notice (...)
	write (3, ...)
end

function syslog.noticef (...)
	writef (3, ...)
end

function syslog.warn (...)
	write (4, ...)
end

function syslog.warnf (...)
	writef (4, ...)
end

function syslog.error (...)
	write (5, ...)
end

function syslog.errorf (...)
	writef (5, ...)
end

function syslog.assert (...)
    assert(...)
end

function syslog.traceback (...)
    traceback(...)
end


syslog.level (1)

return syslog
