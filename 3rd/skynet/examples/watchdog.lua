local skynet = require "skynet"
local netpack = require "netpack"

local CMD = {}
local SOCKET = {}
local gate
local agent = {}

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
    print("----- debug, "..debug.traceback())

	agent[fd] = skynet.newservice("agent") -- 每有一个socket链接，就起一个agent服务
	skynet.call(agent[fd], "lua", "start", { gate = gate, client = fd, watchdog = skynet.self(), addr = addr })
end

local function close_agent(fd)
	local a = agent[fd]
	agent[fd] = nil
	if a then
		skynet.call(gate, "lua", "kick", fd) -- 从gate服务中剔除，断开socket，
		-- disconnect never return
		skynet.send(a, "lua", "disconnect") -- 关掉fd的agent服务
	end
end

function SOCKET.close(fd)
	print("------ socket close",fd)
    print("----- debug, "..debug.traceback())
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
end

function CMD.start(conf)
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.myFunc1(args)
    print("------ calling CMD.myFunc1")
    for k,v in pairs(args) do
        print(k,v)
    end
end

function CMD.close(fd)
	close_agent(fd)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        print(type(session), type(source), type(cmd), type(subcmd))
        -- print(session, source, cmd)
        -- for k,v in pairs(subcmd) do
        --     print(k,v)
        -- end

		if cmd == "socket" then -- 保留给socket的cmd，用于链接，断开等操作
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	gate = skynet.newservice("gate")
end)
