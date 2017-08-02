-- 获取全局的定时器，一个服务只需要一个定时器 update

if g_timer_mgr == nil then
    g_timer_mgr = require "common.timer.timer_mgr"
    g_timer_mgr = g_timer_mgr.new(0.2)
end

return g_timer_mgr

--[[
    -- 使用
    local function hello()
        local timer_mgr4 = require "common.timer.timer_mgr_global"
        print("---- timer_mgr all 222", timer_mgr4)
        syslog.debug("--- testing test")
    end

    local timer_mgr = require "common.timer.timer_mgr_global"
    print("---- timer_mgr all 111", timer_mgr)
    local id = timer_mgr:set_timeout(3, hello, true)
]]

