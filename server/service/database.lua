local skynet = require "skynet"
-- local redis = require "redis"
local redis = require "skynet.db.redis"

local config = require "config.database" -- 数据库配置文件
local account = require "db.account"
local character = require "db.character"
local friend = require "db.friend"
local labor = require "db.labor"
local syslog = require "syslog"

local center
local group = {}
local ngroup

local function hash_str (str) -- string算hash值
	local hash = 0
	string.gsub (str, "(%w)", function (c)
		hash = hash + string.byte (c)
	end)
	return hash
end

local function hash_num (num) -- number算hash值
	local hash = num << 8
	return hash
end

-- 根据key算出一个索引值，索引redis连接池中的某个redis实例，进行存储数据
function connection_handler (key)
	local hash
	local t = type (key)
	if t == "string" then
		hash = hash_str (key)
	else
		hash = hash_num (assert (tonumber (key)))
	end

	return group[hash % ngroup + 1] -- group为redis连接池
end


local MODULE = {}
local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (connection_handler) -- 
end

local traceback = debug.traceback

local CMD = {}
function CMD.open()
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat database")
end


skynet.start (function ()
	module_init ("account", account) -- 不同模块分开处理
    module_init ("character", character)
    module_init ("labor", labor)
	module_init ("friend", friend)

	center = redis.connect (config.center)
	ngroup = #config.group
	for _, c in ipairs (config.group) do -- 初始化链接 ngroup 个redis实例丢进 group连接池中
		table.insert (group, redis.connect (c))
	end

	skynet.dispatch ("lua", function (_, _, mod, cmd, ...)
        local thisf = CMD[mod] -- 本服务的cmd方法
        if thisf then
            syslog.debugf("--- database cmd:%s", mod)
            thisf(cmd, ...)
            return skynet.ret ()
        end

		local m = MODULE[mod] -- 先找对应模块 character
		if not m then
            syslog.errorf("--- no module:%s", mod)
			return skynet.ret ()
		end
		local f = m[cmd] -- 再找对应模块下对应的方法 character.reserve
		if not f then
            syslog.errorf("--- module:%s no cmd:%s", mod, cmd)
			return skynet.ret ()
		end
		
		local function ret (ok, res)
			if not ok then
				skynet.ret ()
                syslog.errorf("--- module:%s exec cmd:%s fail", mod, cmd)
			else
                syslog.debugf("--- module:%s exec cmd:%s success 111", mod, cmd)
				skynet.retpack (res) -- 返回执行结果
                syslog.debugf("--- module:%s exec cmd:%s success 222", mod, cmd)
			end

		end
		ret (xpcall (f, traceback, ...)) -- 执行方法，并返回
	end)
end)
