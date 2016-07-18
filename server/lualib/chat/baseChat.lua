local skynet = require "skynet"

local syslog = require "syslog"
local dbpacker = require "db.packer"

local BaseChat = class("BaseChat")
local LaborTab = {}

function BaseChat:ctor( _chatServer )
    self.chSvr = _chatServer
end

function BaseChat:send( _fd, _name, _msg )
    self.chSvr.send(_fd, _name, { msg = _msg }) -- _name:rpc name
end

return BaseChat


