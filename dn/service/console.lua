local skynet = require "skynet"
local socket = require "socket"

local function readline(sep)
	while true do
		local line = socket.readline(sep)
		if line then
			return line
		end
		coroutine.yield()
	end
end

local function split_package()
	while true do
		local cmd = readline "\n"
		if cmd ~= "" then
			skynet.send(skynet.self(), "text", cmd)
		end
	end
end

local split_co = coroutine.create(split_package)

skynet.register_protocol {
	name = "client",
	id = 3,
	pack = function(...) return ... end,
	unpack = function(msg,sz)
		if sz == 0 then
			skynet.exit()
		else
			socket.push(msg,sz)
			assert(coroutine.resume(split_co))
		end
	end,
	dispatch = function () end
}

local function split_args(text)
	local args = {}
	for a in string.gmatch(text, "%g+") do
		table.insert(args, a)
	end
	return unpack(args)
end

skynet.start(function()
	if skynet.getenv "runasdaemon" ~= "0" then
		skynet.error("can't launch service 'console' in 'runasdaemon' mode")
		skynet.exit()
		return
	end
	skynet.dispatch("text", function (session, address, cmd)
		local handle = skynet.newservice(split_args(cmd))
		if handle == nil then
			print("Launch error:",cmd)
		end
	end)
	socket.stdin()
end)
