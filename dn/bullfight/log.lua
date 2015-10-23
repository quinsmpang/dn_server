local string = string
local table = table
local pairs = pairs
local command = {}
local cmd = require"cmd"
local serverconf = require "serverconf"
local skynet = require"skynet"
local normal_log = {fd = nil, num = 0, maxnum = 10}
local player_log = {fd = nil, num = 0, maxnum = 10, number = 1, filename = nil, err = nil}
local online_log = {fd = nil, num = 0, maxnum = 10, number = 1, filename = nil, err = nil}
local admin_log = {fd = nil, num = 0, maxnum = 10, log = {}, err = nil}
local table_log = {fd = nil, num = 0, maxnum = 10, log = {}, err = nil}

local function fsize (file)
	local current = file:seek() 
	local size = file:seek("end")
	file:seek("set", current) 
	return size
end

local function WriteLog(logtype, body)
	local msg = string.format("[%s] %s %s\n", os.date("%m-%d %H:%M:%S"), logtype, body)
	if not normal_log.fd then
		local file, err = io.open(serverconf.logfile, "a")
		if not file then
			print("open file error", err)
		else
			normal_log.fd = file
		end
	end
	if normal_log.fd then
		normal_log.fd:write(msg)
		normal_log.num = normal_log.num + 1
		if normal_log.num >= normal_log.maxnum then
			local size = fsize(normal_log.fd)
			normal_log.fd:close()
			normal_log.fd = nil
			normal_log.num = 0
			if size >= serverconf.logsize then
				local delname = string.format("%s%d", serverconf.logfile, serverconf.lognum)
				os.remove(delname)
				for i = 1, serverconf.lognum - 1 do
					local oldname = string.format("%s%d", serverconf.logfile, i)
					local newname = string.format("%s%d", serverconf.logfile, i + 1)
					os.rename(oldname, newname)
				end
				local name = string.format("%s%d", serverconf.logfile, 1)
				os.rename(serverconf.logfile, name)
			end
		end
	end
	print(msg)
end

local function WriteAdminLog(body)
	if body then
		table.insert(admin_log.log, body)
		admin_log.num = admin_log.num + 1
	end
	if admin_log.num >= admin_log.maxnum or not body then
		local date = 0
		for k, v in pairs(admin_log.log) do
			local dt = os.date("%Y%m", v.time)
			if dt ~= date then
				date = dt
				if admin_log.fd then
					admin_log.fd:close()
					admin_log.fd = nil
				end
			end
			if not admin_log.fd then
				local file = string.format("admin_log%d.log", date)
				admin_log.fd, admin_log.err = io.open(file, "a")
			end
			local msg = string.format("[%s] %s\n", os.date("%m-%d %H:%M:%S"), body)
			admin_log.fd:write(msg)
		end
		admin_log.fd:close()
		admin_log.fd = nil
		admin_log.log = {}
		admin_log.num = 0
	end
end

local function InitPlayerLog()
	player_log.filename = string.format("player_log%s.log", os.date("%Y%m%d"))
	local fd = io.open(player_log.filename, "rb")
	if not fd then
		player_log.number = 1
	else
		local addr = -2
		fd:seek("end", addr)
		for i = 1, 1000 do
			if fd:read(1) == "\n" then
				player_log.number = fd:read("*n")
				break
			else
				addr = addr - 1
				fd:seek("end", addr)
			end
		end
	end
	player_log.fd, player_log.err = io.open(player_log.filename, "a")
end

local function InitOnLineLog()
	online_log.filename = string.format("online_log%s.log", os.date("%Y%m%d"))
	local fd = io.open(online_log.filename, "rb")
	if not fd then
		online_log.number = 1
	else
		local addr = -2
		fd:seek("end", addr)
		for i = 1, 1000 do
			if fd:read(1) == "\n" then
				online_log.number = fd:read("*n")
				break
			else
				addr = addr - 1
				fd:seek("end", addr)
			end
		end
	end
	online_log.fd, online_log.err = io.open(online_log.filename, "a")
end

local function UpdateLog(log, str)
	if not log.fd then
		log.fd, log.err = io.open(log.filename, "a")
		log.num = 0
	end
	log.fd:write(str)
	log.num = log.num + 1
	if log.num >= log.maxnum then	
		log.fd:close()
		log.fd = nil
		log.num = 0
	end
end

local function WriteLoginLog(msg)
	if msg.uid then
		local file = string.format("player_log%s.log", os.date("%Y%m%d"))
		if player_log.filename ~= file then
			player_log.filename = file
			if player_log.fd then
				player_log.fd:close()
				player_log.fd = nil
			end
			player_log.number = 1
		end
		local str
		if msg.stime then
			str = string.format("%d|1|%d|%d|%d|%s|%d|%d\n", player_log.number, os.time(), msg.uid, msg.typeid, msg.addr, msg.pfid, os.time() - msg.stime)
		else
			str = string.format("%d|1|%d|%d|%d|%s|%d\n", player_log.number, os.time(), msg.uid, msg.typeid, msg.addr, msg.pfid)
		end
		player_log.number = player_log.number + 1
		UpdateLog(player_log, str)
	end
end

local function WriteOnLineLog(num)
	local file = string.format("online_log%s.log", os.date("%Y%m%d"))
	if online_log.filename ~= file then
		online_log.filename = file
		online_log.fd:close()
		online_log.fd = nil
		online_log.number = 1
	end
	local str = string.format("%d|3|%d|%d\n", online_log.number, os.time(), num)
	online_log.number = online_log.number + 1
	UpdateLog(online_log, str)
end

local function WriteMoneyLog(msg)
	local flag = 1
	if msg.addmoney < 0 then
		flag = 2
	end
	local file = string.format("player_log%s.log", os.date("%Y%m%d"))
	if player_log.filename ~= file then
		player_log.fd:close()
		player_log.fd = nil
		player_log.filename = file
		player_log.number = 1
	end
	print(player_log.number == nil, msg.uid == nil, flag == nil, msg.addmoney == nil, msg.curmoney == nil, msg.typeid == nil)
	print(player_log.number, msg.uid, flag, msg.addmoney, msg.curmoney, msg.typeid)
	local str = string.format("%d|2|%d|%d|%d|%d|%d|%d\n", player_log.number, os.time(), msg.uid, flag, msg.addmoney, msg.curmoney, msg.typeid)
	player_log.number = player_log.number + 1
	UpdateLog(player_log, str)
end


local function WriteTableLog(body)
	if body then
		table.insert(table_log.log, body)
		table_log.num = table_log.num + 1
	end
	if table_log.num >= table_log.maxnum or not body then
		local date = 0
		for k, v in pairs(table_log.log) do
			local dt = os.date("%Y%m%d", v.time)
			if dt ~= date then
				date = dt
				if table_log.fd then
					table_log.fd:close()
					table_log.fd = nil
				end
			end
			if not table_log.fd then
				local file = string.format("table_log%d.log", date)
				table_log.fd, table_log.err = io.open(file, "a")
			end
			table_log.fd:write(v)
		end
		table_log.fd:close()
		table_log.fd = nil
		table_log.log = {}
		table_log.num = 0
	end
end


command[cmd.ERROR_LOG] = function(body)
	if serverconf.ERROR_LOG then
		WriteLog("ERROR:", body)
	end
end

command[cmd.DEBUG_LOG] = function(body)
	if serverconf.DEBUG_LOG then
		WriteLog("DEBUG:", body)
	end
end

command[cmd.DAY_LOG] = function(body)
	if serverconf.DAY_LOG then
		WriteLog("DAYLOG:", body)
	end
end

command[cmd.WARMING_LOG] = function(body)
	if serverconf.WARMING_LOG then
		WriteLog("WARMING:", body)
	end
end

command[cmd.MONEY_LOG] = function(body)
	WriteMoneyLog(body)
end

command[cmd.TABLE_LOG] = function(body)
	WriteTableLog(body)
end

command[cmd.ADMIN_LOG] = function(body)
	WriteAdminLog(body)
end

command[cmd.LOGIN_LOG] = function(body)
	WriteLoginLog(body)
end

command[cmd.ON_LINE_LOG] = function(body)
--	WriteOnLineLog(body)
end

command[cmd.EVENT_SERVER_CLOSE] = function(body)
	UpdatePlayerLog(nil)
	WriteTableLog(nil)
	WriteAdminLog(nil)
	player_log.maxnum = 1
	table_log.maxnum = 1
	admin_log.maxnum = 1
	if normal_log.fd then
		normal_log.fd:close()
		normal_log.fd = nil
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		local msg = {...}
		local logtype, body = msg[1], msg[2]
		local f = command[logtype]
		if f then
			f(body)
		else
			print("unknow log type", logtype)
		end
	end)
	skynet.register"CPLog"
	InitPlayerLog()
--	InitOnLineLog()
end)





