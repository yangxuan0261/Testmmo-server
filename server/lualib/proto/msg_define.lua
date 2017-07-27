local MsgDefine = {}

local id_tbl = {
------- 登陆 -------
{name = "rpc_client_handshake"},
{name = "rpc_server_handshake"},
{name = "rpc_client_auth"},
{name = "rpc_server_auth"},
{name = "rpc_client_challenge"},
{name = "rpc_server_challenge"},
{name = "rpc_server_login_gameserver"},

------- 游戏 -------
{name = "rpc_client_user_info"},
{name = "rpc_server_rank_info"},

------- 聊天 -------
{name = "rpc_server_world_chat"},
{name = "rpc_client_word_chat"},
{name = "rpc_client_tips"},

{name = "rpc_server_test_crash"},
{name = "rpc_client_other_login"},
}

local name_tbl = {}

for id,v in ipairs(id_tbl) do
    name_tbl[v.name] = id
end

function MsgDefine.name_2_id(name)
    return name_tbl[name]
end

function MsgDefine.id_2_name(id)
    local v = id_tbl[id]
    return v.name
end

function MsgDefine.get_by_id(id)
    return id_tbl[id]
end

function MsgDefine.get_by_name(name)
    local id = name_tbl[name]
    return id_tbl[id]
end

return MsgDefine
