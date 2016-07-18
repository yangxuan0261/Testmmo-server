local syslog = require "syslog"
local packer = require "db.packer"

local labor = {}
local connection_handler

function labor.init (ch)
	connection_handler = ch
end

local function make_labor_key ()
	return connection_handler ("labor"), "labor"
end

function labor.save (id, data)
	local connection, key = make_labor_key ()
	assert (connection:hset (key, id, data) ~= 0)
	return id
end

function labor.list ()
    syslog.debugf("--- db, labor.list")
    local connection, key = make_labor_key ()
    return connection:hvals (key)
end

return labor

