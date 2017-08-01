local skynet = require "skynet"
local syslog = require "syslog"

local traceback = debug.traceback
local IntervalTime = 5 * 100
local serTab = {}

local CMD = {}
function CMD.open()
    -- local timer_mgr = require "common.timer.timer_mgr"
    -- timer_mgr = timer_mgr.new(0.2)

    -- local function hello()
    --     syslog.debug("--- testing test")
    -- end
    -- local id = timer_mgr:add_timer(3, hello, true)

end

function CMD.register(source, _serName)
    serTab[source] = _serName
end

-- 服务宕机，发邮件通知
local function serviceDump(_serName)
    syslog.errorf("--- Error: service 【%s】 dump!", _serName)
end

local function callService(_addr)
    skynet.call(_addr, "lua", "cmd_heart_beat")
end

--[[
检测各个服务是否宕机
]]
local function heartBeatScheduler()
    -- syslog.debugf("---------- 【heart beat Begin】 ----------")
    for k,v in pairs(serTab) do
        local ok, _ = xpcall (callService, traceback, k)
        if not ok then
            serviceDump(v)
            serTab[k] = nil
        else
            -- syslog.debugf("--- service running:【%s】, addr:%x", v, k)
        end
    end
    -- syslog.debugf("---------- 【heart beat End】 ----------")

    skynet.timeout(IntervalTime, heartBeatScheduler)
end

skynet.start (function ()
    skynet.timeout(IntervalTime, heartBeatScheduler)
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)
