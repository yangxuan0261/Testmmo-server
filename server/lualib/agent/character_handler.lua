local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local dbpacker = require "db.packer"
local handler = require "agent.handler"
local uuid = require "uuid"
local dump = require "common.dump"

local RPC = {}
handler = handler.new (RPC)

local user
local database
local gdd

handler:init (function (u)
	user = u
	database = skynet.uniqueservice ("database")
	gdd = sharedata.query "gdd"
end)

local function load_list (account)
	local list = skynet.call (database, "lua", "character", "list", account)
	if list then
		list = dbpacker.unpack (list)
	else
        print("--- load_list, list is empty")
		list = {}
	end
	return list
end

local function check_character (account, id)
	local list = load_list (account)
	for _, v in pairs (list) do
		if v == id then return true end
	end
	return false
end

function RPC.rpc_server_character_list ()
    syslog.debugf("--- REQUEST.character_list, account:"..user.account)
	local list = load_list (user.account)
	local character = {}
	for _, id in pairs (list) do
        syslog.debugf ("---- REQUEST.character_list, id:%d", id )
		local c = skynet.call (database, "lua", "character", "load", id)

		if c then
             local charData = dbpacker.unpack (c)
            -- dump(charData)
			character[id] = charData
		end
	end
	return { character = character }
end

function RPC.rpc_server_rank_info ( dataTab )
    -- print("-------------------- rpc_server_rank_info ok!")
    dump(dataTab, "--- rank_info")
end

function RPC.rpc_server_test_crash(args )
    -- body
    dump(args, "---------- rpc_server_test_crash")
    user.send_request("rpc_client_user_info", user.info) -- todo: 这里会导致程序崩溃
end

local function create (name, race, class)
	assert (name and race and class)
	assert (#name > 2 and #name < 24)
	assert (gdd.class[class])

	local r = gdd.race[race] or error ()

	local character = { 
		general = {
			name = name,
			race = race,
			class = class,
			map = r.home,
		}, 
		attribute = {
			level = 1,
			exp = 0,
		},
		movement = {
			mode = 0,
			pos = { x = r.pos_x, y = r.pos_y, z = r.pos_z, o = r.pos_o },
		},
	}
	return character
end

function RPC.rpc_server_character_create (args)
    dump(args, "character_create")
	local c = args.character or error ("invalid argument")

	local character = create (c.name, c.race, c.class)
	local id = uuid.gen () -- skynet.call (database, "lua", "character", "reserve", uuid.gen (), c.name)

    syslog.debugf ("--- aaa")
	if not id then return {} end
    syslog.debugf ("--- bbb")

	character.id = id
	local json = dbpacker.pack (character)
	skynet.call (database, "lua", "character", "save", id, json)

	local list = load_list (user.account)
	table.insert (list, id)
	json = dbpacker.pack (list)
	skynet.call (database, "lua", "character", "savelist", user.account, json)

    syslog.debugf ("--- create character success:%d", id)
    dump(character)
	return { character = character }
end

function RPC.rpc_server_character_pick (args)
    syslog.notice (string.format ("--- character_handler, character_pick, id:%d", args.id))

	local id = args.id or error ()
	assert (check_character (user.account, id))

	local c = skynet.call (database, "lua", "character", "load", id) or error ()
	local character = dbpacker.unpack (c)
	user.character = character

	local world = skynet.uniqueservice ("world")
	skynet.call (world, "lua", "cmd_world_character_enter", id)
    syslog.notice (string.format ("--- REQUEST.character_pick, id:%d", id))

	return { character = character }
end

function RPC.rpc_server_character_delete (args)
    syslog.notice (string.format ("--- character_handler, character_delete, id:%d", args.id))
    local id = args.id or error ()
    local list = load_list(user.account)
    local isExit
    for k,v in pairs(list) do
        if v == id then
            isExit = true
            list[k] = nil
            break
        end
    end

    local ret = 0
    if isExit then
        local json = dbpacker.pack (list)
        skynet.call (database, "lua", "character", "savelist", user.account, json)
        ret = skynet.call (database, "lua", "character", "delete", id)
    end
end



attribute_string = {
	"health",
	"strength",
	"stamina",
}

function handler:init_info (character)
	local temp_attribute = {
		[1] = {},
		[2] = {},
	}
	local attribute_count = #temp_attribute

	character.runtime = {
		temp_attribute = temp_attribute,
		attribute = temp_attribute[attribute_count],
	}

	local class = character.general.class
	local race = character.general.race
	local level = character.attribute.level

	local gda = gdd.attribute

	local base = temp_attribute[1]
	base.health_max = gda.health_max[class][level]
	base.strength = gda.strength[race][level]
	base.stamina = gda.stamina[race][level]
	base.attack_power = 0
	
	local last = temp_attribute[attribute_count - 1]
	local final = temp_attribute[attribute_count]

	if last.stamina >= 20 then
		final.health_max = last.health_max + 20 + (last.stamina - 20) * 10
	else
		final.health_max = last.health_max + last.stamina
	end
	final.strength = last.strength
	final.stamina = last.stamina
	final.attack_power = last.attack_power + final.strength

	local attribute = setmetatable (character.attribute, { __index = character.runtime.attribute })

	local health = attribute.health
	if not health or health > attribute.health_max then
		attribute.health = attribute.health_max
	end
end

function handler:save_info (character)
	if not character then return end

	local runtime = character.runtime
	character.runtime = nil
	local data = dbpacker.pack (character) -- pack就是一个cjson的encode
	character.runtime = runtime
	skynet.call (database, "lua", "character", "save", character.id, data)
end

return handler

