local skynet = require "skynet"
local syslog = require "syslog"
local timer = require "common.timer.timer"

local timer_mgr = {}
local mt = { __index = timer_mgr }
local _interval
local _timer_tbl = {}
local _id = 1

local function update()
    for k,v in pairs(_timer_tbl) do
        if v:update() == "over" then
            _timer_tbl[k] = nil
        end
    end
end

local function scheduler()
    update()
    skynet.timeout(_interval, scheduler)
end

function timer_mgr.new (interval)
    syslog.noticef("--- timer_mgr.new, create a scheduler in %s ", SERVICE_NAME)
        
    _interval = interval or 0.2
    _interval = _interval * 100

    skynet.timeout(_interval, scheduler)
    return setmetatable ({}, mt)
end

function timer_mgr:set_timeout(interval, func)
    local function wrapFunc()
        func()
        return "over"
    end
    return self:add_timer(interval, wrapFunc, false)
end

function timer_mgr:add_timer(interval, func, isNow)
    assert(_timer_tbl[_id] == nil, "timer_mgr:add_timer is not nil")
    local id = _id
    local t = timer.new(interval, func, isNow)
    _timer_tbl[id] = t
    _id = _id + 1
    return id
end

function timer_mgr:remove_timer(id)
    if _timer_tbl[id] then
        _timer_tbl[id] = nil
    end
end

function timer_mgr:get_timer(id)
    if _timer_tbl[id] then
        return _timer_tbl[id]
    end
end

function timer_mgr:stop()
    for k,v in pairs(_timer_tbl) do
        _timer_tbl[k] = nil
    end
end

return timer_mgr