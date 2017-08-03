local constant = require "constant"
local srp = require "srp"
local dbpacker = require "db.packer"

local syslog = require "syslog"
-- local assert = syslog.assert

local CMD = {}
local connection_handler

function CMD.init (ch)
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

local function make_accInfo_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "info", account)
end

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "friends", account)
end

function CMD.cmd_account_load_by_name (name)
	assert (name)
	local acc = { name = name }
	local connection, key = make_key (name) 
	if connection:exists (key) then
		acc.id = connection:hget (key, "account")
		acc.salt = connection:hget (key, "salt")
		acc.verifier = connection:hget (key, "verifier")
        syslog.debugf ("--- connection:exists, name:%s", name)
	else
		acc.salt, acc.verifier = srp.create_verifier (name, constant.default_password)
        syslog.debugf ("--- connection: no exists, name:%s", name)

	end
    if acc.verifier == nil then
        syslog.errorf ("--- acc.verifier is nil")
        assert(acc.verifier, "-------- acc.verifier is nil")
    end

    acc = dbpacker.pack (acc)
	return acc
end

function CMD.cmd_account_create (id, name, password)
	assert (id and name and #name < 24 and password and #password < 24, "invalid argument")

	local connection, key = make_key (name)
    assert (connection:hsetnx (key, "account", id) ~= 0, "create account failed account")
	assert (connection:hsetnx (key, "username", name) ~= 0, "create account failed username")

	local salt, verifier = srp.create_verifier (name, password)
    if verifier == nil then
        syslog.errorf ("--- cmd_account_create, verifier is nil, name:%s", name)
    end
    assert (connection:hsetnx (key, "salt", salt) ~= 0, "create account failed salt")
    assert (connection:hsetnx (key, "verifier", verifier) ~= 0, "create account failed verifier")

    connection, key = make_list_key ()
    assert (connection:sadd (key, id) ~= 0, "create account failed")
	return id
end

function CMD.loadlist ()
    connection, key = make_list_key ()
    return connection:smembers (key) or {}
end

function CMD.cmd_account_loadInfo( account )
    local connection, key = make_accInfo_key (account)
    return connection:get (key)
end

function CMD.cmd_account_saveInfo( account, json )
    local connection, key = make_accInfo_key (account)
    assert (connection:set (key, json) ~= 0, "saveInfo failed")
    return true
end

return CMD
