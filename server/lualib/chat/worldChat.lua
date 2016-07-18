local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local BaseChat = require "chat.baseChat"

local WorldChat = class("WorldChat", BaseChat)

function WorldChat:ctor( ... ) 
    WorldChat.super.ctor(self, ...)
end


return WorldChat


