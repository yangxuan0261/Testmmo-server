local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local BaseChat = require "chat.baseChat"

local FriendChat = class("FriendChat", BaseChat)

function FriendChat:ctor( ... ) 
    FriendChat.super.ctor(self, ...)

end


return FriendChat


