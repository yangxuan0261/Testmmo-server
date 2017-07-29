-- 网络消息封包解包
local Utils = require "common.utils"
local msg_define = require "proto.msg_define"

--- 客户端使用版本，服务端已废弃
local ProtoPacker = {}

-- 包格式
-- 两字节包长
-- 两字节协议号
-- 两字符字符串长度
-- 字符串内容
function ProtoPacker.pack(proto_name, msg)
	local proto_id = msg_define.name_2_id(proto_name)
    local params_str = Utils.table_2_str(msg)
    local len = 2 + #params_str
    local data = Utils.int16_2_bytes(proto_id) .. Utils.int16_2_bytes(#params_str) .. params_str
    return data	
end

function ProtoPacker.unpack(data)
	local proto_id = data:byte(1) * 256 + data:byte(2)
	local params_str = data:sub(3+2)
	local proto_name = msg_define.id_2_name(proto_id)
    return proto_name, params_str	
end

return ProtoPacker
