
local friend = {}
local connection_handler

function friend.init (ch)
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

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%d", account)
end

local function make_accInfo_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "info", account)
end

local function make_friend_key (account)
    return connection_handler (account), string.format ("user:%s_%d", "friends", account)
end


function friend.saveFriend( account, friend, data )
    local connection, key = make_friend_key (account)
    assert (connection:hset (key, friend, data) ~= 0, "saveFriend failed")
    return true
end

function friend.delFreind( account, friend )
    local connection, key = make_friend_key (account)
    assert (connection:hdel (key, friend) ~= 0, "delFreind failed")
    return true
end

function friend.loadFreind( account, friend )
    local connection, key = make_friend_key (account)
    return connection:hget (key, friend)
end

function friend.loadFreindList( account )
    local connection, key = make_friend_key (account)
    return connection:hvals (key) or {}
end

return friend
