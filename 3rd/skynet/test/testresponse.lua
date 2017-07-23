local skynet = require "skynet"

local CMD = {}
function CMD.method_1( args )
    skynet.sleep(500)
    print("--- method1, arg:"..args.num)
    return "RetFromMethod1"
end

function CMD.method_2( args )
    skynet.sleep(500)
    print("--- method2, arg:"..args.num)
    return "RetFromMethod2"
end

function CMD.method_3( args )
    skynet.sleep(500)
    print("--- method3, arg:"..args.num)
end

function CMD.method_4( args )
    skynet.sleep(500)
    print("--- method4, arg:"..args.num)
end

function CMD.method_5( args )
    skynet.sleep(500)
    print("--- method5, arg:"..args.num)
end

local mode = ...

if mode == "TICK" then
-- this service whould response the request every 1s.

local response_queue = {} -- 请求队列

local function response()
	while true do
		skynet.sleep(100)	-- sleep 1s
		for k,v in ipairs(response_queue) do
            -- v(true, "exec:"..skynet.now())      -- true means succ, false means error
			v.resp(true, "exec:"..skynet.now()..", retValue:"..v.ret)		-- true means succ, false means error
			response_queue[k] = nil
		end
	end
end

skynet.start(function()
    print("------ testresponse service start 111")
	skynet.fork(response)
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        local retValue = f(subcmd, ...) or "defalut"
        local struct = {
            ret = retValue,
            resp = skynet.response(),
        }
		table.insert(response_queue, struct)
	end)
end)

else

local function request(tick, i)
	print(i, "call", skynet.now())
	print(i, "response", skynet.call(tick, "lua", "method_"..i, {
          num = 111 * i
          }))
	print(i, "end", skynet.now())
end

skynet.start(function()
    print("------ testresponse service start 222")
    print("------ SERVICE_NAME, type:"..type(SERVICE_NAME)..", value:"..SERVICE_NAME) -- SERVICE_NAME, type:string, value:testresponse -- 当前服务的名字
	local tick = skynet.newservice(SERVICE_NAME, "TICK") --启动自己的服务，TICK 模式 mode == "TICK"

	for i=1,5 do
		skynet.fork(request, tick, i)
		skynet.sleep(300)
	end
end)

end
--[[
[:01000011] LAUNCH snlua testresponse
------ testresponse service start 222
------ SERVICE_NAME, type:string, value:testresponse
[:01000012] LAUNCH snlua testresponse TICK
------ testresponse service start 111
1   call    40
2   call    340
--- method1, arg:111
1   response    exec:540, retValue:defalut
1   end 540
3   call    640
--- method2, arg:222
2   response    exec:840, retValue:defalut
2   end 840
4   call    940
--- method3, arg:333
3   response    exec:1140, retValue:defalut
3   end 1140
5   call    1240
--- method4, arg:444
4   response    exec:1440, retValue:defalut
4   end 1440
[:01000009] KILL self
[:01000002] KILL self
--- method5, arg:555
5   response    exec:1740, retValue:defalut
5   end 1740
]]
