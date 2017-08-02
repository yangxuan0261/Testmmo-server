package.cpath = package.cpath .. ";../3rd/skynet/luaclib/?.so;../server/luaclib/?.so"
package.path = package.path .. ";../3rd/skynet/lualib/?.lua;../server/lualib/?.lua"
package.path = package.path .. ";../?.lua;"

-- local print_r = require "common.dump"
local socket = require "client.socket"
local sproto = require "sproto"
local srp = require "srp"
local aes = require "aes"

local Utils = require "common.utils"
local MsgDefine = require "proto.msg_define"

local username = arg[1]
local password = arg[2]
print("----------------- begin, ", username, password)

-- local constant = {default_password = "123abcDef$%^"}
local constant = require "common.constant"

local user = { name = username, password = password }

if not user.name then
	local f = io.open ("anonymous", "r")
	if not f then
		f = io.open ("anonymous", "w")
		local name = ""
		math.randomseed (os.time ())
		for i = 1, 16 do
			name = name .. string.char (math.random (127))
		end

		user.name = name
		f:write (name)
		f:flush ()
		f:close ()
	else
		user.name = f:read ("a")
		f:close ()
	end
end

if not user.password then
	user.password = constant.default_password
end

local server = "127.0.0.1"
local login_port = 9777
local game_port = 9555
local gameserver = {
	addr = "127.0.0.1",
	port = 9555,
	name = "gameserver",
}

local fd 
local game_fd

local function send_request (name, args)
    print("------------- send_request", name, args)

    local proto_id = MsgDefine.name_2_id(name)
    local params_str = Utils.table_2_str(args)
    local len = 2 + 2 + #params_str
    local data = Utils.int16_2_bytes(len) .. Utils.int16_2_bytes(proto_id) .. Utils.int16_2_bytes(#params_str) .. params_str
    socket.send (fd, data)
end

local function unpack (text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte (1) * 256 + text:byte (2)
    -- print("--- s", size, s)--- s    201 199

	if size < s + 2 then
		return nil, text
	end

	return text:sub (3, 2 + s), text:sub (3 + s)
end

local function recv (last)
	local result
	result, last = unpack (last)
	if result then
		return result, last
	end
	local r = socket.recv (fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error (string.format ("socket %d closed", fd))
	end

	return unpack (last .. r)
end

local rr = { wantmore = true, myStr = "hello world" }
local function handle_request (name, args, response) -- 处理服务端的请求
    print ("^^^@ request from server", name)
    
	if args then
		-- print_r (args)
	else
		print "empty argument"
	end
end

local RESPONSE = {}

function RESPONSE.rpc_client_handshake (args)
	local name = user.name
	if args.user_exists then
    print ("RESPONSE.handshake --- exit")
		local key = srp.create_client_session_key (name, user.password, args.salt, user.private_key, user.public_key, args.server_pub)
		user.session_key = key
		local ret = { challenge = aes.encrypt (args.challenge, key) }
		send_request ("rpc_server_auth", ret)
	else
    print ("RESPONSE.handshake --- not exit")
		print (name, constant.default_password)
		local key = srp.create_client_session_key (name, constant.default_password, args.salt, user.private_key, user.public_key, args.server_pub)
		user.session_key = key
		local ret = { challenge = aes.encrypt (args.challenge, key), password = aes.encrypt (user.password, key) }
		send_request ("rpc_server_auth", ret)
	end
end

function RESPONSE.rpc_client_auth (args)
	print ("RESPONSE.auth")

	user.session = args.session
	local challenge = aes.encrypt (args.challenge, user.session_key)
	send_request ("rpc_server_challenge", { session = args.session, challenge = challenge })
end

function RESPONSE.rpc_client_challenge (args)
	print ("-------------------- RESPONSE.challenge, login ok, toker get!!!")

	-- local token = aes.encrypt (args.token, user.session_key)

	-- fd = assert (socket.connect (gameserver.addr, gameserver.port))
	-- print (string.format ("game server connected, fd = %d", fd))
	-- send_request ("login", { session = user.session, token = token })



	-- send_request ("character_list")
end


local function handle_message (data)
    local proto_id = data:byte(1) * 256 + data:byte(2)
    local params_str = data:sub(3+2)
    -- print(proto_id, params_str)
    local proto_name = MsgDefine.id_2_name(proto_id)
    local paramTab = Utils.str_2_table(params_str)
    local f = RESPONSE[proto_name]
    if f then
        f(paramTab)
    else
        print("--- handle_response, not found func:"..s.name)
    end
end

local last = ""
local function dispatch_message ()
	while true do
		local v
		v, last = recv (last)
		if not v then
			break
		end

		handle_message (v) -- sproto解析来自服务端的数据（服务端也是用sproto编码，所以这里用它解码）
	end
end

local private_key, public_key = srp.create_client_key ()
user.private_key = private_key
user.public_key = public_key 
fd = assert (socket.connect (server, login_port))
-- print (string.format ("login server connected, fd = %d", fd))
send_request ("rpc_server_handshake", { name = user.name, client_pub = public_key })

local HELP = {}

--[[
lua client.lua aaa bbb
-- id:3149323469594823681

lua client.lua ccc ddd
-- id:3149323469594823681

cd client
./run
character_create character = { name = "yang", race = "human", class = "warrior" }
character_list
character_pick id = 3148166985225864193
map_ready
move pos = { x = 123, z = 321 }
combat target = 7
test1
]]

local mycmd = {}
mycmd[1] = { character = { name = "yang", race = "human", class = "warrior" } }
mycmd[11] = { character = { name = "xuan", race = "human", class = "warrior" } }
mycmd[2] = { }
mycmd[3] = { id = 3149323469594823681 }
mycmd[13] = { id = 3149323823929624577 }
mycmd[4] = { }
mycmd[5] = { pos = { x = 123, z = 321 }}
mycmd[15] = { pos = { x = 129, z = 329 }}
mycmd[6] = { pos = { x = 120, z = 310 }}
mycmd[16] = { pos = { x = 0, z = 10 }}
mycmd[7] = { target = 7 }
mycmd[8] = { arg1 = 456, arg2 = "aaa"}

function CmdParser( cmdStr )
    -- body
    local strTab = {}
    local rets = string.gmatch(cmdStr, "%S+")
    for i in (rets) do
        table.insert(strTab, i)
    end
    local argTab = {}
    local cmd = strTab[1]

    if cmd == "create" then
        cmd = "character_create"
        argTab = {
            character = { 
                name = strTab[2],
                race = strTab[3],
                class = strTab[4]
            }
        }

    elseif cmd == "pick" then
        cmd = "character_pick"
        local ids = {
            [1] = 3149323469594823681,
            [2] = 3151658778605126657
        }
        argTab = { id = ids[tonumber(strTab[2])] }

    elseif cmd == "list" then
        cmd = "character_list"

    elseif cmd == "move" then
        argTab = {
            pos = {
                x = tonumber(strTab[2]),
                y = tonumber(strTab[3])
            }
        }

    elseif cmd == "enter" then
        cmd = "map_ready"

    elseif cmd == "atk" then
        cmd = "combat"
        argTab = { target = tonumber(strTab[2]) }

    end

    return cmd, argTab
end

local function handle_cmd (line)
    local cmd, t = CmdParser(line)
	-- local cmd
	-- local p = string.gsub (line, "([%w-_]+)", function (s) 
	-- 	cmd = s
	-- 	return ""
	-- end, 1)
 --    local t = mycmd[tonumber(p)]

    --[[
	print (cmd, "====", p)

	if string.lower (cmd) == "help" then
		for k, v in pairs (HELP) do
			print (string.format ("command:\n\t%s\nparameter:\n%s", k, v()))
		end
		return
	end

    print("--- load type:", type(load))

    local f, err = load (p, "=(load)" , "t", t)

	if not f then error (err) end
	f ()

	print ("----- cmd", cmd)
	if t then
		print_r (t)
	else
		print ("--- null argument")
	end

	if not next (t) then t = nil end
]]
    if not next (t) then t = nil end

	if cmd then
		local ok, err = pcall (send_request, cmd, t)
		if not ok then
			print (string.format ("invalid command (%s), error (%s)", cmd, err))
		end
	end
end

function HELP.character_create ()
	return [[
	name: your nickname in game
	race: 1(human)/2(orc)
	class: 1(warrior)/2(mage)
]]
end

-- print ('type "help" to see all available command.')
while true do
	dispatch_message ()
	-- local cmd = socket.readstdin ()
	-- if cmd then
	-- 	handle_cmd (cmd)
	-- else
		socket.usleep (500)
	-- end
end

