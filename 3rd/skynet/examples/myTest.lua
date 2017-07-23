local skynet = require "skynet"
local CMD = {}

function CMD.testFunc(args)
    -- print("------ calling CMD.testFunc")
    -- for k,v in pairs(args) do
    --     print(k,v)
    -- end

    return "ret msg from myTest service, testFunc"
end

skynet.init(function()
    print("------ myTest service init")
end)

skynet.start(function()
    print("------ myTest service start")
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        print("---------- myTest rec msg 111111")
        print(type(session), type(source), type(cmd))
        print(session, source, cmd)
        -- local f = assert(CMD[cmd])
        skynet.ret(skynet.pack("")) -- 处理消息，并返回，返回时都要pack一下
        skynet.exit()
    end)
    -- skynet.exit()
end)
