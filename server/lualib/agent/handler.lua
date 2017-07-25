-- agent所有handler的父类

local handler = {}
local mt = { __index = handler }

function handler.new (rpc, cmd)
	return setmetatable ({
		init_func = {},
		rpc = rpc,
		cmd = cmd,
	}, mt)
end

function handler:init (f)
	table.insert (self.init_func, f)
end

local function merge (dest, t) -- 复制表元素
	if not dest or not t then return end
	for k, v in pairs (t) do
		dest[k] = v
	end
end

function handler:register (user)
	for _, f in pairs (self.init_func) do
		f (user)
	end

	merge (user.RPC, self.rpc)
	merge (user.CMD, self.cmd)
end

local function clean (dest, t)
	if not dest or not t then return end
	for k, _ in pairs (t) do
		dest[k] = nil
	end
end

function handler:unregister (user)
	clean (user.RPC, self.rpc)
	clean (user.CMD, self.cmd)
end

return handler
