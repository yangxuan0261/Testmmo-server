local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local BaseChat = require "chat.baseChat"

local LaborChat = class("LaborChat", BaseChat)
local LaborTab = {}

function LaborChat:ctor( ... ) -- 初始化工会数据
    LaborChat.super.ctor(self, ...)
    local keys = {} -- redis getkeys
    for _, v in pairs(keys) do
        local accTab = {} -- redis get key 
        LaborTab[v] = accTab
    end
end

function LaborChat:broadcast( _laborId, _acc, _msg )
    local accTab = LaborTab[_laborId]
    assert(accTab, "Error: LaborChat:broadcast, not found labor:".._laborId)

    for _,v in pairs(accTab) do

    end
end


return LaborChat


