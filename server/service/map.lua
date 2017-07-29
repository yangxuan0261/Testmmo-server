local skynet = require "skynet"
local syslog = require "syslog"
local aoi = require "map.aoi"


local world
local conf

local pending_character = {}
local online_character = {}
local CMD = {}

function CMD.init (w, c)
	world = w
	conf = c
	aoi.init (conf.bbox, conf.radius)
end

function CMD.cmd_map_character_enter (_, agent, character)
	syslog.noticef ("--- CMD.cmd_map_character_enter, character(%d) loading map", character)

	pending_character[agent] = character
	skynet.call (agent, "lua", "cmd_map_enter", skynet.self ())
end

function CMD.cmd_map_character_leave (agent)
	local character = online_character[agent] or pending_character[agent]
	if character ~= nil then
		syslog.noticef ("character(%d) leave map", character)
		local ok, list = aoi.remove (agent) -- 返回我的视野列表
		if ok then
			skynet.call (agent, "lua", "cmd_aoi_manage", nil, list)
		end
	end
	online_character[agent] = nil
	pending_character[agent] = nil
end

function CMD.character_ready (agent, pos)
	if pending_character[agent] == nil then return false end
	online_character[agent] = pending_character[agent]
	pending_character[agent] = nil

	syslog.noticef ("--- agent:%d, character:%d enter map", agent, online_character[agent])

	local ok, list = aoi.insert (agent, pos) -- 返回我的视野列表
	if not ok then 
        syslog.debugf ("--- aoi.insert, not ok")
        return false 
    end

	skynet.call (agent, "lua", "cmd_aoi_manage", list)
	return true
end

function CMD.move_blink (agent, pos)
	local ok, add, update, remove = aoi.update (agent, pos)
	if not ok then return end
	skynet.call (agent, "lua", "cmd_aoi_manage", add, remove, update, "move")
	return true
end

function CMD.open (conf)
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat map")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)
