-------------- mydump begin --------------
local syslog = require "syslog"
local tostring = tostring
local type = type
local string = string
local pairs = pairs

local tab_space = "    "
local function  get_tab_space(deepth)
    local str = ""
    for i=1,deepth do
        str = str .. tab_space
    end
    return str
end

local function mydump_tbl(tbl, deepth)
    if type(tbl) ~= "table" then return end
    deepth = deepth or 1
    local str = string.format("{\n")
    -- local str = string.format(""%s{ %s\n", get_tab_space(deepth - 1), tostring(tbl)) -- 打出table地址

    for k,v in pairs(tbl) do
        assert(type(k) ~= "table", "dont allow key = table")
        k = tostring(k)
        local line = string.format("%s\"%s\" = ", get_tab_space(deepth), k)
        if type(v) == "table" then
            line = string.format("%s%s,\n", line, mydump_tbl(v, deepth + 1))
        else
            line = string.format("%s%s,\n", line, tostring(v))
        end
        str = str .. line
    end

    str = string.format("%s%s}", str, get_tab_space(deepth - 1))
    return str
end


local function mydump(obj, descr)
    descr = descr or "mydump"
    local info = string.format("\"%s\" = ", descr)
    if type(obj) == "table" then
        info = info .. mydump_tbl(obj, 2)
    else
        info = info .. tostring(obj)
    end
    -- info = string.format("%s\n-- %s end--", info, descr)
    syslog.debugf(info)
end

return mydump
-------------- mydump end --------------

-- local tconcat = table.concat
-- local tinsert = table.insert
-- local srep = string.rep
-- local type = type
-- local pairs = pairs
-- local tostring = tostring
-- local next = next
-- local syslog = require "syslog"

-- local function print_r(root, descr)
--     descr = descr or "--- dump"
--     syslog.debugf("%s, type:%s", descr, type(root))
--     if root == nil then return end
--     local cache = {  [root] = "." }
--     local function _dump(t,space,name)
--         local temp = {}
--         for k,v in pairs(t) do
--             local key = tostring(k)
--             if cache[v] then
--                 tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
--             elseif type(v) == "table" then
--                 local new_key = name .. "." .. key
--                 cache[v] = new_key
--                 tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
--             else
--                 tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
--             end
--         end
--         return tconcat(temp,"\n"..space)
--     end
--     syslog.debugf("%s", _dump(root, "",""))
-- end

-- return print_r







-- local print = print
-- local tconcat = table.concat
-- local tinsert = table.insert
-- local srep = string.rep
-- local type = type
-- local pairs = pairs
-- local tostring = tostring
-- local next = next

-- local function print_r(root)
-- 	local cache = {  [root] = "." }
-- 	local function _dump(t,space,name)
-- 		local temp = {}
-- 		for k,v in pairs(t) do
-- 			local key = tostring(k)
-- 			if cache[v] then
-- 				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
-- 			elseif type(v) == "table" then
-- 				local new_key = name .. "." .. key
-- 				cache[v] = new_key
-- 				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
-- 			else
-- 				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
-- 			end
-- 		end
-- 		return tconcat(temp,"\n"..space)
-- 	end
-- 	print(_dump(root, "",""))
-- end

-- function string.split(input, delimiter)
--     input = tostring(input)
--     delimiter = tostring(delimiter)
--     if (delimiter=='') then return false end
--     local pos,arr = 0, {}
--     -- for each divider found
--     for st,sp in function() return string.find(input, delimiter, pos, true) end do
--         table.insert(arr, string.sub(input, pos, st - 1))
--         pos = sp + 1
--     end
--     table.insert(arr, string.sub(input, pos))
--     return arr
-- end

-- function string.trim(input)
--     input = string.gsub(input, "^[ \t\n\r]+", "")
--     return string.gsub(input, "[ \t\n\r]+$", "")
-- end

-- local function dump_value_(v)
--     if type(v) == "string" then
--         v = "\"" .. v .. "\""
--     end
--     return tostring(v)
-- end

-- local function dump(value, desciption, nesting)
--     if type(nesting) ~= "number" then nesting = 3 end

--     local lookupTable = {}
--     local result = {}

--     local traceback = string.split(debug.traceback("", 2), "\n")
--     print("dump from: " .. string.trim(traceback[3]))

--     local function dump_(value, desciption, indent, nest, keylen)
--         desciption = desciption or "<var>"
--         local spc = ""
--         if type(keylen) == "number" then
--             spc = string.rep(" ", keylen - string.len(dump_value_(desciption)))
--         end
--         if type(value) ~= "table" then
--             result[#result +1 ] = string.format("%s%s%s = %s", indent, dump_value_(desciption), spc, dump_value_(value))
--         elseif lookupTable[tostring(value)] then
--             result[#result +1 ] = string.format("%s%s%s = *REF*", indent, dump_value_(desciption), spc)
--         else
--             lookupTable[tostring(value)] = true
--             if nest > nesting then
--                 result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, dump_value_(desciption))
--             else
--                 result[#result +1 ] = string.format("%s%s = {", indent, dump_value_(desciption))
--                 local indent2 = indent.."    "
--                 local keys = {}
--                 local keylen = 0
--                 local values = {}
--                 for k, v in pairs(value) do
--                     keys[#keys + 1] = k
--                     local vk = dump_value_(k)
--                     local vkl = string.len(vk)
--                     if vkl > keylen then keylen = vkl end
--                     values[k] = v
--                 end
--                 table.sort(keys, function(a, b)
--                     if type(a) == "number" and type(b) == "number" then
--                         return a < b
--                     else
--                         return tostring(a) < tostring(b)
--                     end
--                 end)
--                 for i, k in ipairs(keys) do
--                     dump_(values[k], k, indent2, nest + 1, keylen)
--                 end
--                 result[#result +1] = string.format("%s}", indent)
--             end
--         end
--     end
--     dump_(value, desciption, "- ", 1)

--     for i, line in ipairs(result) do
--         print(line)
--     end
-- end

-- return dump
