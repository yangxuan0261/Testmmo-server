local constant = require "constant"
local srp = require "srp"


local account = {}
local connection_handler

function account.init (ch)
	connection_handler = ch
end

-- 返回 redis实例 和 user map的key
local function make_key (name)
	return connection_handler (name), string.format ("user:%s", name)
end

local UserList = "UserList"
local function make_list_key ()
    return connection_handler (UserList), string.format ("%s", UserList)
end

local function make_account_key (account)
    return connection_handler (account), string.format ("user:%d", account)
end

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "friends", account)
end

function account.load (name)
	assert (name)

	local acc = { name = name }

	local connection, key = make_key (name) 
	if connection:exists (key) then
		acc.id = connection:hget (key, "account")
		acc.salt = connection:hget (key, "salt")
		acc.verifier = connection:hget (key, "verifier")
	else
		acc.salt, acc.verifier = srp.create_verifier (name, constant.default_password)
	end

	return acc
end

function account.create (id, name, password)
	assert (id and name and #name < 24 and password and #password < 24, "invalid argument")

	local connection, key = make_key (name)
	assert (connection:hsetnx (key, "account", id) ~= 0, "create account failed")

	local salt, verifier = srp.create_verifier (name, password)
	assert (connection:hmset (key, "salt", salt, "verifier", verifier) ~= 0, "save account verifier failed")

    -- save to list
    account.savelist(id)
	return id
end

function account.savelist (account)
    connection, key = make_list_key ()
    connection:sadd (key, id)
end

function account.loadlist ()
    connection, key = make_list_key ()
    return connection:smembers (key)
end

function account.loadInfo( account )
    assert (account)
    local connection, key = make_account_key (account)
    return connection:hget (key, "info")
end

function account.saveInfo( account, json )
    local connection, key = make_account_key (account)
    assert (connection:hset (key, "info", json) ~= 0, "saveInfo failed")
end

function account.saveFriend( account, friend, data )
    local connection, key = make_friend_key (account)
    assert (connection:hset (key, friend, data) ~= 0, "saveFriend failed")
end

function account.delFreind( account, friend )
    local connection, key = make_friend_key (account)
    assert (connection:hdel (key, friend) ~= 0, "delFreind failed")
    return true
end

function account.loadFreind( account, friend )
    local connection, key = make_friend_key (account)
    return connection:hget (key, friend)
end

function account.loadFreindList( account )
    local connection, key = make_friend_key (account)
    return connection:hvals (key) or {}
end

return account
