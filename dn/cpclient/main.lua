local skynet = require "skynet"

skynet.start(function()
	print("Test start")
--	local lualog = skynet.launch("snlua","lualog")
	local launcher = skynet.newservice("launcher")
--	local group_mgr = skynet.launch("snlua", "group_mgr")
--	local group_agent = skynet.launch("snlua", "group_agent")
--	local remoteroot = skynet.launch("snlua","remote_root")
--	local console = skynet.launch("snlua","console")
--	local watchdog = skynet.launch("snlua","watchdog","8888 4 0")
--	local db = skynet.launch("snlua","simpledb")
	local connection = skynet.launch("connection","2560")
	skynet.sleep(100)
--	local rbdb = skynet.launch("snlua","rbdb")
	local rbdb = skynet.newservice("rbdb")
--	for i = 10, 13 do
	for i = 5, 91 do
		if i ~= 4 then
			local uid = tostring(i)
--		local client = skynet.newservice("client", "3")--uid)
--			skynet.sleep(100)
			local client = skynet.newservice("client", uid)--uid)
		end
	end
--	local client = skynet.launch("snlua", "client", 10)
--	local client1 = skynet.launch("snlua", "client", 11)
--	local redis = skynet.launch("snlua","redis-mgr")
--	skynet.launch("snlua","testgroup")
	--local test = skynet.launch("snlua", "sicbo_client")
	skynet.exit()
end)
