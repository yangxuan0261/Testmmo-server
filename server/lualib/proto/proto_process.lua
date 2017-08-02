local driver = require "skynet.socketdriver"
local Utils = require "common.utils"
local MsgDefine = require "proto.msg_define"
local syslog = require "syslog"
local dump = require "common.dump"
local xpcall = xpcall
-- local  traceback = syslog.traceback
local  traceback = debug.traceback

-- rpc 读写
local ProtoProcess = {}

ProtoProcess.Write = function(fd, protoName, msgTab)
    -- local function writeFunc()
        local id = MsgDefine.name_2_id(protoName)
        local msg_str = Utils.table_2_str(msgTab)
        local len = 2 + 2 + #msg_str
        local data = string.pack(">HHs2", len, id, msg_str)
        -- syslog.debugf("--- ProtoProcess.Write, proto:%s", protoName)
        driver.send (fd, data)
    -- end
    -- xpcall(writeFunc, traceback) -- 貌似加了 xpcall 容易出问题，code dumped
end

-------------------
ProtoProcess.ReadMsg = function(msg)
    -- local function readFunc()
        local proto_id, params = string.unpack(">Hs2", msg)
        local proto_name = MsgDefine.id_2_name(proto_id)
        local param_tbl = Utils.str_2_table(params)
        -- syslog.debugf("--- ProtoProcess.ReadMsg, proto:%s", proto_name)
        return proto_name, param_tbl
    -- end
    -- local ok, proto_name, param_tbl = xpcall(readFunc, traceback) -- 貌似加了 xpcall 容易出问题，code dumped
    -- return proto_name, param_tbl
end

return ProtoProcess
