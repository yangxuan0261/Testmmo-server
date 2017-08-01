local socket = require "skynet.socket"
local Utils = require "common.utils"
local MsgDefine = require "proto.msg_define"
local syslog = require "syslog"
local dump = require "common.dump"

-- rpc 读写
local ProtoProcess = {}

ProtoProcess.Write = function(fd, protoName, msgTab)
    local id = MsgDefine.name_2_id(protoName)
    local msg_str = Utils.table_2_str(msgTab)
    local len = 2 + 2 + #msg_str
    local data = string.pack(">HHs2", len, id, msg_str)
    -- syslog.debugf("--- ProtoProcess.Write, proto:%s", protoName)
    socket.write (fd, data)
end

-------------------
ProtoProcess.ReadMsg = function(msg)
    print("--- ReadMsg:", msg)
    local proto_id, params = string.unpack(">Hs2", msg)
    local proto_name = MsgDefine.id_2_name(proto_id)
    local paramTab = Utils.str_2_table(params)
    -- syslog.debugf("--- ProtoProcess.ReadMsg, proto:%s", proto_name)
    return proto_name, paramTab
end

return ProtoProcess
