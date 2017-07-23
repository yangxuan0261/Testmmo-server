local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"

local server = {
	host = "127.0.0.1",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

local server_list = {}
local user_online = {}
local user_login = {}

function server.auth_handler(token) -- step 8，客户端token处理，user信息的认证
    print("--- server.auth_handler, token:", token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	assert(password == "password", "Invalid password") -- 模拟从数据库取信息比对
	return server, user
end

function server.login_handler(server, uid, secret) -- step 9
	print(string.format("--- server.login_handler, %s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))

    print("----------------------- server_list -------------")
    for k,v in pairs(server_list) do
        print(k,v)
    end
    print("----------------------- server_list -------------")

	local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then -- 踢掉之前登陆的对象
		skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local subid = tostring(skynet.call(gameserver, "lua", "login", uid, secret, "myFlag"))
	user_online[uid] = { address = gameserver, subid = subid , server = server}
	return subid -- step 10-1， 引擎会把状态码和这个subid打包发给客户端
end

local CMD = {}

function CMD.register_gate(server, address)
    print("--- CMD.register_gate", server, address)
    -- print("------ "..debug.traceback())
	server_list[server] = address
end

function CMD.logout(uid, subid)
    print("--- CMD.logout", uid, subid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function server.command_handler(command, ...)
    print("--- server.command_handler")
    local f = assert(CMD[command])
    return f(...)
end

login(server)
print("----------- logind")
