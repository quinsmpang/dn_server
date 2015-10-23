local skynet = require "skynet"
local types = require "types"

skynet.start(function()
	skynet.timeout(100, function()
	end)
	print("Server start")
--	local service = skynet.launch("snlua","service_mgr")
	local service = skynet.newservice("service_mgr")
	local connection = skynet.launch("connection","256")
--	local lualog = skynet.launch("snlua","lualog")
	local lualog = skynet.newservice("lualog")
	local cplog = skynet.newservice("log")
--	local redis = skynet.launch("snlua","redis-mgr")
	local redis = skynet.newservice("redis-mgr")
	local mysql = skynet.newservice("database")
	skynet.sleep(300)
	local myredis = skynet.newservice("myredis")
	if skynet.getenv"console" then  
	--	local rconsole = skynet.launch("snlua","rconsole")
		local rconsole = skynet.newservice("rconsole")
    end
--	local console = skynet.launch("snlua","console")
	local shop = skynet.newservice("shop")
	local bullfight = skynet.newservice("bfgame")
	local room = skynet.newservice("room")
	local cpcenter = skynet.newservice("playercenter")
	skynet.sleep(100)
	local watchdog = skynet.newservice("watchdog","8004",  "20000",  "0", "S", types.server_name["watchdog"]["S"])
--	local watchdog = skynet.newservice("watchdog","8005 20000 0", "W", types.server_name["watchdog"]["W"])
	local watchdog = skynet.newservice("adminwatchdog","8006",  "100", "0", "S", types.server_name["watchdog"]["A"])

	skynet.exit()
end)
