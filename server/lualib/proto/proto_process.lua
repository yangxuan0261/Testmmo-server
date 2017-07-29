local socket = require "skynet.socket"
local Utils = require "common.utils"
local MsgDefine = require "proto.msg_define"
local netpack = require "skynet.netpack"

-- rpc 读写
local ProtoProcess = {}

local function read (fd, size)
    return socket.read (fd, size) or error ()
end

ProtoProcess.Read = function(fd)
    local s = read (fd, 2)
    local size = s:byte(1) * 256 + s:byte(2)
    local msg = read (fd, size)
    local proto_id, params = string.unpack(">Hs2", msg)
    local proto_name = MsgDefine.id_2_name(proto_id)
    local paramTab = Utils.str_2_table(params)
    return proto_name, paramTab
end

ProtoProcess.Write = function(fd, protoName, msgTab)
    local id = MsgDefine.name_2_id(protoName)
    local msg_str = Utils.table_2_str(msgTab)
    local len = 2 + 2 + #msg_str
    local data = string.pack(">HHs2", len, id, msg_str)
    socket.write (fd, data)
end

-------------------
ProtoProcess.ReadMsg = function(msg, sz)
    local msg22 = netpack.tostring(msg, sz)
    local proto_id, params = string.unpack(">Hs2", msg22)
    local proto_name = MsgDefine.id_2_name(proto_id)
    local paramTab = Utils.str_2_table(params)
    return proto_name, paramTab
end

return ProtoProcess
