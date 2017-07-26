local cjson = require("cjson")

local Utils = {}

------------ 用 cjson 做序列化 begin -----------
Utils.table_2_str = function (obj)
    return cjson.encode(obj)
end

Utils.str_2_table = function (str)
    return cjson.decode(str)
end
------------ 用 cjson 做序列化 end -----------

function Utils.int16_2_bytes(num)
	local high = math.floor(num/256)
	local low = num % 256
	return string.char(high) .. string.char(low)
end

function Utils.bytes_2_int16(bytes)
	local high = string.byte(bytes,1)
	local low = string.byte(bytes,2)
	return high*256 + low
end

return Utils