local skynet = require "skynet"
local cmd = require "cmd"

local port, max_agent, buffer, ptype, service_name = ...
local command = {}
local client_all = {}
local event = {}
local gate
local errcode = require"errorcode"
local serverconf = require"serverconf"

local admin = {}

local function WriteLog(logtype, msg)
	local body = string.format("admin %s", msg)
	skynet.send("CPLog", "lua", logtype, body)
end

local function Send(client, succ)
	if client_all[client] then
		local addr = skynet.address(client_all[client])
		if succ then
			skynet.send(addr, 3, "true")
		else
			skynet.send(addr, 3, "false")
		end
	end
end

admin[cmd.ADMIN_ADD_MONEY] = function(client, body)
	local uid, addid, money = string.match(body, "(%d+) (%d+) ([+-]?%d+)")
	uid, addid, money = tonumber(uid), tonumber(addid), tonumber(money)
	local ret = skynet.call("CPCenter", "lua", cmd.ADMIN_ADD_MONEY, addid, uid, money)
	if ret then
		local m = {uid = uid, id = addid, type = 1, money = money}
		skynet.send("mysql", "lua", cmd.SQL_WRITE_SYSTEM_EMAIL, m)
	end
	Send(client, ret)
end

admin[cmd.ADMIN_ADD_DTMONEY] = function(client, body)
	local uid, addid, dtmoney = string.match(body, "(%d+) (%d+) ([+-]?%d+)")
	uid, addid, dtmoney = tonumber(uid), tonumber(addid), tonumber(dtmoney)
	local ret = skynet.call("CPCenter", "lua", cmd.ADMIN_ADD_DTMONEY, addid, uid, dtmoney)
	if ret then
		local m = {uid = uid, id = addid, type = 3, dtmoney = dtmoney}
		skynet.send("mysql", "lua", cmd.SQL_WRITE_SYSTEM_EMAIL, m)
	end
	Send(client, ret)
end

admin[cmd.ADMIN_BROADCAST] = function(client, body)
	local num, msg = string.match(body, "(%d+) (.*)")
	num = tonumber(num)
	msg = tostring(msg)
	skynet.send("CPCenter", "lua", cmd.ADMIN_BROADCAST, num, msg)
	Send(client, true)
end

admin[cmd.ADMIN_KICK_PLAYER] = function(client, body)
	local uid = string.match(body, "(%d+)")
	uid = tonumber(uid)
	skynet.send("CPCenter", "lua", cmd.ADMIN_KICK_PLAYER, uid)
end

admin[cmd.ADMIN_SERVER_CLOSE] = function(client, body)
	skynet.send("CPCenter", "lua", cmd.ADMIN_SERVER_CLOSE)
	Send(client, true)
end

admin[cmd.ADMIN_BLOCKED_PLAYER] = function(client, body)
	local uid, starttime, endtime, adminid, resean = string.match(body, "(%d+) (%d+) (%d+) (%d+) ?(.*)")
	local conf = {
		uid = tonumber(uid),
		starttime = tonumber(starttime),
		endtime = tonumber(endtime),
		adminid = tonumber(adminid),
		state	= 1,
		resean = resean
	}
	if conf.endtime == 0 then
		conf.state = 0
	end
	local ret = skynet.call("mysql", "lua", cmd.SQL_BLOCKED_PLAYER, conf)
	skynet.send("CPCenter", "lua", cmd.ADMIN_BLOCKED_PLAYER, conf.uid, conf.endtime)
	Send(client, ret)
end

admin[cmd.ADMIN_SOMEONE_SHOP] = function(client, body)
	local order_nu = body
	local succ = false
	skynet.send("CPLog", "lua", cmd.ADMIN_LOG, string.format("recv order:%s", order_nu))
	local result = skynet.call("mysql", "lua", cmd.SQL_GET_ORDER, order_nu)
	if result and #result ~= 0 then
		local conf = {
			fid = tonumber(result[1][1]), --充值用户
			goodsid = tonumber(result[1][2]), -- 商品号
			ordertype = tonumber(result[1][3]), -- 支付类型(0 金币 1 大头币 2 游戏币)
			coin_price = tonumber(result[1][4]), -- 商品单价
			count = tonumber(result[1][5]), -- 购买数量
			uid = tonumber(result[1][6]), -- 赠送uid
			order_nu = order_nu, -- 订单号
			isshop = true
		}
		local ret = skynet.call("mysql", "lua", cmd.SQL_FIRST_BUYER, conf.fid)
		if ret then
			if #ret == 0 then
				conf.firstbuy = 0
			else
				conf.firstbuy = 1
			end
		else
			skynet.send("CPLog", "lua", cmd.ADMIN_LOG, string.format("get first_buyer error:%s", conf.fid))
		end
		succ = skynet.call("Shop", "lua", cmd.EVENT_SHOP, conf)
	else
		skynet.send("CPLog", "lua", cmd.ADMIN_LOG, string.format("get order error:%s", order_nu))
	end
	Send(client, succ)
end

admin[cmd.ADMIN_SEND_TOOL] = function(client, body)
	local uid, fid, toolid, count, notice, resean = string.match(body, "(%d+) (%d+) (%d+) (%d+) ?(.*)")
	local conf = {
		uid = tonumber(uid),
		fid = tonumber(fid),
		goodsid = tonumber(toolid),
		count = tonumber(count),
		notice = tonumber(notice),--notice = 0 表示通知玩家, 1 不通知玩家
		resean = resean
	}
	local succ = skynet.call("Shop", "lua", cmd.EVENT_SHOP, conf)
	Send(client, succ)
	skynet.send("CPLog", "lua", cmd.ADMIN_LOG, string.format("admin %d send %d to %d, num:%d, %s", conf.fid, conf.goodsid, conf.uid, conf.count, conf.resean))
end

admin[cmd.ADMIN_UPDATE_NOTICE] = function(client, body)
	local succ = skynet.call("CPCenter", "lua", cmd.ADMIN_UPDATE_NOTICE)
	Send(client, succ)
end

admin[cmd.ADMIN_CHANGE_SF_PWD] = function(client, body)
	local uid, pwd = string.match(body, "(%d+) ?(.*)")
	local msg = {uid = tonumber(uid), pwd = pwd}
	local succ = skynet.call("CPCenter", "lua", cmd.ADMIN_CHANGE_SF_PWD, msg)
	Send(client, succ)
end

admin[cmd.ADMIN_UPDATE_ROOMCONF] = function(client, body)
	skynet.send("CPRoom", "lua", cmd.ADMIN_UPDATE_ROOMCONF)
	Send(client, true)
end

admin[cmd.ADMIN_UPDATE_TOOLCONF] = function(client, body)
	skynet.send("Shop", "lua", cmd.ADMIN_UPDATE_TOOLCONF)
	Send(client, true)
end

function command:open(parm)
	local fd,addr = string.match(parm,"(%d+) ([^%s]+)")
	fd = tonumber(fd)
	local client = skynet.launch("client", fd, gate, self)
	client_all[self] = client
end 

function command:close()
	print("agent close", self, string.format("close %d", self))
	client_all[self] = nil
end

function command:data(data, session)
--	local message = skynet.tostring(data, string.len(data))
	local key, type, body = string.match(data, "(%w+) (%d+) ?(.*)")
	print(key)
	type = tonumber(type)
	local client = self
	if key == serverconf.admin_key then
		local f = admin[tonumber(type)]
		if f then
			f(client, body)
		else
			print("Unknow client command:", type)
		end
	else
		print("key error:", key)
	end
end

skynet.register_protocol{
	name = "client",
	id = 3,
	pack = function(...) return ... end,
	unpack = function(...) return ... end,
}

skynet.start(function()
	skynet.dispatch("text", function(session, from, message)
		print("@@@@@@##########message", message)
		local id, cmd, parm = string.match(message, "(%d+) (%w+) ?(.*)")
		print("admin recv:", cmd, " msg:", parm)
		id = tonumber(id)
		local f = command[cmd]
		if f then
			f(id, parm, session)
		else
			error(string.format("[watchdog] Unknown command : %s",message))
		end
	end)
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local type = body[1]
		body[1] = address
		local f = event[type]
		if f then
			f(body)
		else 
			print("unknow message", cmd)
		end
	end)

	gate = skynet.launch("gate", ptype, skynet.address(skynet.self()), port, 0, max_agent, buffer)
	skynet.send(gate, "text", "start")
	skynet.register(service_name)
end)
