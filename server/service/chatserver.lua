require "functions"
local skynet = require "skynet"
local syslog = require "syslog"
local socket = require "socket"
local protoloader = require "protoloader"

local FriendChat = require "chat.friendChat"
local LaborChat = require "chat.laborChat"
local WorldChat = require "chat.worldChat"
-- local gamed = tonumber (...)

local agentTab = {}
local accountTab = {}

local ChatServer = {}
ChatServer.agentTab = agentTab 
ChatServer.accountTab = accountTab 

local friendHandler
local laborHandler
local worldHandler

--------------- send begin --------------

local _, proto_request = protoloader.load (protoloader.GAME)

local function send_msg (fd, msg)
    local package = string.pack (">s2", msg)
    socket.write (fd, package)
end

-- local session = {}
local session_id = 0
local function send_request (user_fd, name, args)
    session_id = session_id + 1
    local str = proto_request (name, args, session_id)
    send_msg (user_fd, str)
    -- session[session_id] = { name = name, args = args }
end
ChatServer.send = send_request
--------------- send end --------------


local CMD = {}
function CMD.open (source, conf)
    syslog.debugf("--- chat server open")
    friendHandler = FriendChat.new(ChatServer)
    laborHandler = LaborChat.new(ChatServer)
    worldHandler = WorldChat.new(ChatServer)
end

function CMD.join( _agent, _account, _fd )

    local _friList = {} -- redis get friends
    local _labor = 0 -- redis get labor

    local info = {
        agent = _agent,
        account = _account,
        fd = _fd,
        labor = _labor,
        friendList = _friList, 
    }

    agentTab[_agent] = info
    accountTab[_account] = info
end

function CMD.leave( _agent )
    local info = agentTab[_agent]
    assert(info, "Error: CMD.leave, agent:".._agent)

    agentTab[_agent] = nil
    accountTab[info.account] = nil
end

function CMD.friendChat( _agent, _friend, _msg )
    local friInfo = accountTab[_friend]
end

function CMD.laborChat( _agent, _msg )
    
end

function CMD.worldChat( _agent )

end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warningf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warningf ("handle message(%s) failed : %s", command, ret)
            kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)


