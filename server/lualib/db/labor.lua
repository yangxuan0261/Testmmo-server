local syslog = require "syslog"
local packer = require "db.packer"

local labor = {}
local connection_handler

function labor.init (ch)
	connection_handler = ch
end

local LaborList = "LaborList"
local function make_list_key( ... )
    return connection_handler (LaborList), string.format ("%s", LaborList)
end

local function make_labor_key (id)
	return connection_handler (id), string.format ("labor:%d", id)
end

function labor.saveInfo (id, data)
	local connection, key = make_labor_key (id)
	assert (connection:hset (key, id, data) ~= 0)

    labor.savelist (id)
	return id
end

function labor.loadInfo (id)
    local connection, key = make_labor_key (id)
    return connection:hget (key, id)
end

function labor.savelist (id)
    connection, key = make_list_key ()
    assert (connection:sadd (key, id) ~= 0)
    return true
end

function labor.loadlist ()
    syslog.debugf("--- db, labor.loadlist")
    connection, key = make_list_key ()
    return connection:smembers (key) or {}
end

return labor

