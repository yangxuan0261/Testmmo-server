local skynet = require "skynet"

local config = require "config.system"

local syslog = {
	prefix = {
        "D| ",
		"I| ",
		"N| ",
		"W| ",
		"E| ",
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

syslog.level (tonumber (config.log_level) or 3)

return syslog
