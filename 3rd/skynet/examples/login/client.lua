package.cpath = "luaclib/?.so" -- 1. 定义so库的搜索路径

local socket = require "clientsocket" -- 2. 包含 clientsocket.so 库
local crypt = require "crypt"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

print("\n--- connect to loginServer begin")
local fd = assert(socket.connect("127.0.0.1", 8001))

local function writeline(fd, text)
	socket.send(fd, text .. "\n")
end

local function unpack_line(text)
	local from = text:find("\n", 1, true)
	if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end

local last = ""

local function unpack_f(f)
	local function try_recv(fd, last)
		local result
		result, last = f(last)
		if result then
			return result, last
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
        print("---------- r:", r)
		return f(last .. r)
	end

	return function()
		while true do
			local result
			result, last = try_recv(fd, last)
			if result then
                -- print("------- result:", result)
				return result
			end
			socket.usleep(100)
		end
	end
end

local readline = unpack_f(unpack_line)

local challenge = crypt.base64decode(readline()) -- step 1-2, 接收服务端下行的随机数据
print("--- challenge is ", challenge)

local clientkey = crypt.randomkey()
writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey))) -- step 2-1，客户端生成随机数据
local secret = crypt.dhsecret(crypt.base64decode(readline()), clientkey) -- step 4-2，收到服务端生成的serverkey， 和客户端的随机数据生成secret

print("--- sceret is ", crypt.hexencode(secret)) -- 服务端下发的 sceret

local hmac = crypt.hmac64(challenge, secret) -- step 5，客户端生成hmac
writeline(fd, crypt.base64encode(hmac)) -- step 6-1，上行给服务端做最后的握手校验，还不是登陆校验

local token = { -- 客户端生成的的token
	server = "sample",
	user = "hello",
	pass = "password",
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

local etoken = crypt.desencode(secret, encode_token(token))
local b = crypt.base64encode(etoken)
writeline(fd, crypt.base64encode(etoken)) -- step 7

local result = readline() -- step 10-2, 前三位是状态码，后几位是subid
print("--- @@@ ### loginServer result is:", result)
local code = tonumber(string.sub(result, 1, 3))
assert(code == 200)
socket.close(fd) -- 断掉登陆服

local subid = crypt.base64decode(string.sub(result, 5))

print("login ok, subid=", subid) -- 登陆成功，开始连接游戏服

----- connect to game server

local function send_request(v, session)
	local size = #v + 4
	local package = string.pack(">I2", size)..v..string.pack(">I4", session)
	socket.send(fd, package)
	return v, session
end

local function recv_response(v)
	local size = #v - 5
	local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
	return ok ~=0 , content, session
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
    -- print("--- receive:", text)
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
    print("--- unpack_package:", text:sub(3,2+s), text:sub(3+s), s)
	return text:sub(3,2+s), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local text = "echo"
local index = 1


print("\n--- connect to gameServer begin")
fd = assert(socket.connect("127.0.0.1", 8888)) -- 连接游戏服，这里可以换成登录成功下发的服务器列表的ip和端口，让用户选择进哪个服
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
print("--- handshake:", handshake)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print("--- @@@ ### gameServer result is:", readpackage())
print("===>",send_request(text,0))
-- don't recv response
-- print("<===",recv_response(readpackage()))

print("------ simulate disconnect from gameServer")
socket.close(fd)

index = index + 1

print("--- connect gameServer again")
fd = assert(socket.connect("127.0.0.1", 8888)) -- 重连游戏服
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print("--- @@@ ### second connect, gameServer result is:", readpackage())
print("===>",send_request("fake",0))	-- request again (use last session 0, so the request message is fake)
print("===>",send_request("again",1))   -- request again (use new session)
print("===>",send_request("hello",2))   -- request again (use new session)
print("===>",send_request("world",3))	-- request again (use new session)
print("<===",recv_response(readpackage()))
print("<===",recv_response(readpackage()))
print("<===",recv_response(readpackage()))
print("<===",recv_response(readpackage()))


print("disconnect")
socket.close(fd)

