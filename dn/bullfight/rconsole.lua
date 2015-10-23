local skynet = require "skynet"
local binding = skynet.getenv"console"

local gate
local command = {}
local client
function command:open(param)
	print("open", param)
	local fd,addr = string.match(param,"(%d+) ([^%s]+)")
	fd = tonumber(fd)
	local c = skynet.launch("client",fd, gate, self)
	if client then
		skynet.send(c, "text", "Only support one connection!")
	else
		client = c
		skynet.send(client, "text", "Connected to console.")
	end
end

function command:close()
	skynet.kill(client)
	client = nil
end

local function split_args(data)
	local args = {}
	for a in string.gmatch(data, "%g+") do
		table.insert(args, a)
	end
	return unpack(args)
end

function command:data(data, session)
	local handle = skynet.newservice(split_args(data))
	local result
	if not handle then
		skynet.send(client, "text", "launch service '"..data.."' failed.")
	end

end

skynet.start(function()
	skynet.dispatch("text", function(session, from, message)
		local id, cmd , parm = string.match(message, "(%d+) (%w+) ?(.*)")
		id = tonumber(id)
		local f = command[cmd]
		if f then
			f(id,parm,session)
		else
			error(string.format("[console] Unknown command : %s",message))
		end
	end)
	skynet.dispatch("lua", function(session, from, message)
		assert(type(message)=="string")
		if client then
			skynet.send(client, "text", message)
		end
	end)
	-- 0 for default client tag
	gate = skynet.launch("gate" , "S" , skynet.address(skynet.self()), binding, 0, 10, 0)
	skynet.send(gate,"text", "start")
	skynet.register".console"
end)
