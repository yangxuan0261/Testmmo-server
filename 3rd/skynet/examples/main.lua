local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
require "skynet.manager"    -- import skynet.launch, ...

local max_client = 64

skynet.start(function()
	skynet.error("Server start")
	skynet.uniqueservice("protoloader")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",8000)
	skynet.newservice("simpledb")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})

	skynet.error("Watchdog listen on", 8888)
--[[
    -- test
    -- local myTest = skynet.newservice("myTest")
    local ok, myTest = pcall(skynet.newservice, "myTest") --这种方式启动可以容错
    if not ok then
        print("------ myTest service start fail")
    else
        skynet.name(".myTest", myTest) -- 注册一个服务名，str，这个api在skynet.manager中，必须要require进来，否则报错

        -- 用地址
        -- skynet.call(myTest, "lua", "testFunc", {
        -- aaa = "bbb",
        -- ccc = "ddd",
        -- eee = "fff",
        -- })

        -- 用服务名
        local retMsg = skynet.call(".myTest", "lua", "testFunc", {
        zzz = "www",
        xxx = "eee",
        ccc = "rrr",
        })

        print("------ retMsg:"..retMsg)
    end
]]
    -- test timeout
    -- pcall(skynet.newservice, "time")

    -- pcall(skynet.newservice, "testresponse")

    -- pcall(skynet.newservice, "testmongodb")

    -- pcall(skynet.newservice, "testcoroutine")

    -- test config
    -- local cfg1 = skynet.getenv "myConfig1"
    -- local cfg2 = skynet.getenv "myConfig2"
    -- print("cfg1, type:"..type(cfg1)..", value:"..cfg1)
    -- print("cfg2, type:"..type(cfg2)..", value:"..cfg2)
    -- cfg1, type:string, value:hello world
    -- cfg2, type:string, value:123456



	skynet.exit()
end)
