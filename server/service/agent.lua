local skynet = require "skynet"
local queue = require "skynet.queue"
local sharemap = require "skynet.sharemap"
local socket = require "skynet.socket"
local dbpacker = require "db.packer"
local FlagDef = require "config.FlagDef"
local dump = require "common.dump"
local ProtoProcess = require "proto_2.proto_process"
local syslog = require "syslog"

----------- all handler begin ------------
local character_handler = require "agent.character_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"
local combat_handler = require "agent.combat_handler"
local gm_handler = require "agent.gm_handler"
local world_handler = require "agent.world_handler"
local friend_handler = require "agent.friend_handler"
local labor_handler = require "agent.labor_handler"
----------- all handler end ------------

local gamed = tonumber (...)
local database
local user
local user_fd
local session = {}
local session_id = 0

local assert = syslog.assert

local DefaultName = "Tim"


local function send_request (name, args)
    ProtoProcess.Write (user_fd, name, args)
end

local Utils = require "common.utils"
local msg_define = require "proto_2.msg_define"

local function kick_self ()
    if true then
        syslog.debugf ("--- kick_self, traceback:", debug.traceback())
        return
    end

	skynet.call (gamed, "lua", "kick", skynet.self (), user_fd)
end

local last_heartbeat_time
local HEARTBEAT_TIME_MAX = 0 -- 3 * 100 -- 3秒钟未收到消息，则判断为客户端失联
local function heartbeat_check ()
	if HEARTBEAT_TIME_MAX <= 0 or not user_fd then return end

	local t = last_heartbeat_time + HEARTBEAT_TIME_MAX - skynet.now ()
	if t <= 0 then
        syslog.debugf ("--- heatbeat:%s, last:%s, now:%s", HEARTBEAT_TIME_MAX, last_heartbeat_time, skynet.now() )

		syslog.warning ("--- heatbeat check failed, exe kick_self()")
		kick_self ()
	else
		skynet.timeout (t, heartbeat_check)
	end
end

local traceback = debug.traceback
local RPC = {} -- 在各个handler中各种定义处理，模块化，但必须确保函数不重名，所以一般 模块名_函数名
-- local function handle_request (name, args, response)
-- 	local f = REQUEST[name]
-- 	if f then
--         syslog.debugf ("--- 【C>>S】, request from client: %s", name)
-- 		local ok, ret = xpcall (f, traceback, args)
-- 		if not ok then
-- 			syslog.warningf ("handle message(%s) failed : %s", name, ret) 
-- 			kick_self ()
-- 		else
-- 			last_heartbeat_time = skynet.now () -- 每次收到客户端端请求，重新计时心跳时间
-- 			if response and ret then -- 如果该请求要求返回，则返回结果
-- 				send_msg (user_fd, response (ret))
-- 			end
-- 		end
-- 	else
-- 		syslog.warningf ("----- unhandled message : %s", name)
-- 		kick_self ()
-- 	end
-- end

-- local RESPONSE
-- local function handle_response (id, args)
-- 	local s = session[id] -- 检查是否存在此次会话
-- 	if not s then
-- 		syslog.warningf ("Error, session %d not found", id)
-- 		kick_self ()
-- 		return
-- 	end

-- 	local f = RESPONSE[s.name] -- 检查是否存在user.send_request("aaa", xxx)中对应的响应方法 RESPONSE.aaa
-- 	if not f then
-- 		syslog.warningf ("unhandled response : %s", s.name)
-- 		kick_self () -- 不存在则踢下线，因为可能会话被篡改
-- 		return
-- 	end

--     syslog.debugf ("--- 【C>>S】, response from client: %s", s.name)
-- 	local ok, ret = xpcall (f, traceback, s.args, args) 
-- 	if not ok then
-- 		syslog.warningf ("handle response(%d-%s) failed : %s", id, s.name, ret) 
-- 		kick_self ()
-- 	end
-- end

local function my_unpack(msg, sz)
    return ProtoProcess.ReadMsg(msg, sz)
end

local function my_dispatch(source, session, proto_name, ...)
    local f = RPC[proto_name]
    if f then
        f(...)
    end
end

skynet.register_protocol { -- 注册与客户端交互的协议
	name = "client",
	id = skynet.PTYPE_CLIENT,
    unpack = my_unpack,
    dispatch = my_dispatch,
}

local CMD = {}

function CMD.open (fd, account)
	syslog.debugf ("-------- agent opened:"..account)
    database = skynet.uniqueservice ("database")

    local info = skynet.call (database, "lua", "account", "loadInfo", account)
    if info then
        info = dbpacker.unpack(info)
    else
        info = {
            account = account,
            nickName = DefaultName,
            laborId = nil,
        }
    end
    dump(info, "--- agent info")

	user = { 
		fd = fd, 
		account = account,
        info = info,
		RPC = {},
		CMD = CMD,
		send_request = send_request,
	}
	user_fd = user.fd
	RPC = user.RPC

    user.FlagDef = FlagDef

    character_handler:register (user)
    labor_handler:register(user)
    friend_handler:register(user)
    world_handler:register(user)

    -- gm register
    gm_handler:register(user)

	last_heartbeat_time = skynet.now () -- 开启心跳
	heartbeat_check ()

    -- get in
    -- skynet.fork(function()
        local chatserver = skynet.uniqueservice ("chat_server")
        local friendserver = skynet.uniqueservice ("friend_server")
        local laborserver = skynet.uniqueservice ("labor_server")
        skynet.call (chatserver, "lua", "cmd_online", user.account)
        skynet.call (friendserver, "lua", "cmd_online", user.account)
        skynet.call (laborserver, "lua", "cmd_online", user.account)
    -- end)

    -- send info to client
    local json = dbpacker.pack(info)
    local tmpTab = {hello = 111, world = 999}
    send_request("user_info_svr", tmpTab)
end

function CMD.close ()
    syslog.debugf ("--- agent closed, traceback:")

	local account
	if user then
		account = user.account

		if user.map then -- 先离开 地图
			skynet.call (user.map, "lua", "character_leave")
			user.map = nil
			map_handler:unregister (user)
			aoi_handler:unregister (user)
			move_handler:unregister (user)
			combat_handler:unregister (user)
		end

		if user.world then -- 后离开 世界
			skynet.call (user.world, "lua", "character_leave", user.character.id)
			user.world = nil
		end
        -- dump(user.info, "--- userInfo")
        local json = dbpacker.pack(user.info)
        skynet.call (database, "lua", "account", "saveInfo", account, json)

            -- get out, can fork, user will nil
        -- skynet.fork(function()
            local chatserver = skynet.uniqueservice ("chat_server")
            local friendserver = skynet.uniqueservice ("friend_server")
            local laborserver = skynet.uniqueservice ("labor_server")
            skynet.call (chatserver, "lua", "cmd_offline", user.account)
            skynet.call (friendserver, "lua", "cmd_offline", user.account)
            skynet.call (laborserver, "lua", "cmd_offline", user.account)
        -- end)

		character_handler.save (user.character) -- 保存角色数据

        character_handler:unregister (user)
        labor_handler:unregister(user)
        friend_handler:unregister(user)
        world_handler:unregister(user)
        gm_handler:unregister(user)

		user = nil
		user_fd = nil
		RPC = nil
	end

    -- 通知服务器关掉这个agent的socket
	skynet.call (gamed, "lua", "close", skynet.self (), account)
end

function CMD.kick ()
	error ()
	syslog.debugf ("agent kicked")
	skynet.call (gamed, "lua", "kick", skynet.self (), user_fd)
end

function CMD.world_enter (world)
	local name = string.format ("agent:%d:%s", user.character.id, user.character.general.name)
    syslog.noticef (string.format ("--- agent, world_enter, name:%s", name))


	character_handler.init (user.character)

	user.world = world
    syslog.noticef (string.format ("--- agent, world_enter, character_handler:unregister"))

	return user.character.general.map, user.character.movement.pos
end

function CMD.map_enter (map)
    syslog.noticef (string.format ("--- agent, map_enter"))

	user.map = map

	map_handler:register (user)
	aoi_handler:register (user)
	move_handler:register (user)
	combat_handler:register (user)
end

skynet.start (function ()
    syslog.debugf("我了个去")

	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = CMD[command]
		if not f then
			syslog.warn("unhandled message(%s)", command) 
			return skynet.ret ()
		end

		local ok, ret = xpcall (f, traceback, ...)
		if not ok then
			syslog.warn ("handle message(%s) failed : %s", command, ret) 
			kick_self ()
			return skynet.ret ()
		end
		skynet.retpack (ret)
	end)
end)

