local skynet = require "skynet"

skynet.start(function()
	print("Server start")
	local service = skynet.newservice("service_mgr")
	local connection = skynet.launch("connection","256")
	local lualog = skynet.newservice("lualog")
	local console = skynet.newservice("console")
	local watchdog = skynet.newservice("watchdog",8888, 4, 0)
	local db = skynet.newservice("simpledb")
	skynet.exit()
	print("main exit")
end)
