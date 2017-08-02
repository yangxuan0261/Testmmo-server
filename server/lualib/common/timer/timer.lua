-- print(skynet.starttime())
-- print(skynet.now())

-- skynet.timeout(1, function()
--     print("in 1", skynet.now())
-- end)
local skynet = require "skynet"

local timer = {}
local mt = { __index = timer }

function timer.new (interval, func, isNow)
    assert(interval and interval > 0 and func)
    if isNow then
        func()
    end

    return setmetatable ({
                 _start_time = skynet.now(),
                 _interval = interval * 100,
                 _func = func,
            }, mt)
end

function timer:update ()
    if (skynet.now() - self._start_time) > self._interval then
        -- print("--- timer:update,", self._start_time, skynet.now())
        self._start_time = skynet.now()
        return self._func()
    end
end

function timer:reset ()
    self._start_time = skynet.now()
end

return timer