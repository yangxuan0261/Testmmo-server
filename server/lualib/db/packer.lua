-- local cjson = require "cjson"
-- cjson.encode_sparse_array(true, 1, 1)
local Utils = require "common.utils"


local packer = {}

function packer.pack (v)
	return Utils.table_2_str(v)
end

function packer.unpack (v)
	return Utils.str_2_table(v)
end

return packer
