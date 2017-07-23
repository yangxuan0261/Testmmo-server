local skynet = require "skynet"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
}

local gate
local userid, subid

local CMD = {}

function CMD.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	skynet.error(string.format("%s is login", uid))
	gate = source -- 游戏服地址
	userid = uid
	subid = sid
	-- you may load user data from database
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", userid, subid)
	end
	skynet.exit()
end

function CMD.logout(source)
    print("--- msgagent, logout", debug.traceback())
	-- NOTICE: The logout MAY be reentry
	skynet.error(string.format("%s is logout", userid))
	logout()
end

function CMD.afk(source)
	-- the connection is broken, but the user may back
	skynet.error(string.format("--- AFK"))
end

skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(source, ...)))
	end)

	skynet.dispatch("client", function(_,_, msg)
		-- the simple echo service
		skynet.sleep(10)	-- sleep a while
		skynet.ret("------ client msg:"..msg) -- 直接返回给客户端
        local test = skynet.newservice("myTest") -- 把登陆服的addr传入gated中，gated中 的 ... 就是指这里传进的不定参数

        skynet.call(test, "lua", "open" , {
        port = 8888,
        maxclient = 64,
        servername = "sample",
    })
	end)
end)
