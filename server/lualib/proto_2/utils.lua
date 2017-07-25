local cjson = require("cjson")

local M = {}

------------ 用 cjson 做序列化 begin -----------
M.table_2_str = function (obj)
    return cjson.encode(obj)
end

M.str_2_table = function (str)
    -- local tmp = cjson.decode(str)
    -- print("------------------ type:", type(tmp))
    return cjson.decode(str)
end
------------ 用 cjson 做序列化 end -----------

function M.int16_2_bytes(num)
	local high = math.floor(num/256)
	local low = num % 256
	return string.char(high) .. string.char(low)
end

function M.bytes_2_int16(bytes)
	local high = string.byte(bytes,1)
	local low = string.byte(bytes,2)
	return high*256 + low
end

return M