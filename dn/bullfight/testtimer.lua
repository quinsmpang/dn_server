local skynet = require "skynet"
local timer = require "timer"

local function cb(...)
	print("timeout ", ...)
end

skynet.start(function()
	local timer1 = timer.new()
	timer1:start(500, cb, "timer1")
	local timer2 = timer.new()
	timer2:start(300, cb, "timer2")
	timer1:remove()
end)
