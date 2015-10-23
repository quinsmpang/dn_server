local skynet = require "skynet"
local cmd = require "cmd"
local errcode = require "errorcode"
local types = require "types"
local serverconf = require "serverconf"
local myclib = require"myclib"
local task = require"taskconf"
local MSG = require "gamepacket"
local all_player = {}
local command = {}
local blocked_player = {}
local server_close = false
local today = os.date("%d")
--local today = 21
local uplose = {}

local function SendTo(uid, mtype, ...)
	local msg
	if mtype then
		msg = MSG.pack(mtype, ...)
	else
		msg = ...
	end
	if all_player[uid] then
		pcall(skynet.send, all_player[uid].address, "relay", msg)
	end
end

local function WriteOnLineCount()
	skynet.timeout(serverconf.T_ON_LINE, function()
		local num = {}
		for k, v in pairs(serverconf.pfid) do
			num[v] = 0
		end
		for k, v in pairs(all_player) do
			for i, j in pairs(serverconf.pfid) do
				if all_player[k].sqlpfid == j then
					num[j] = num[j] + 1	
				end
			end
		end
		skynet.send("mysql", "lua", cmd.SQL_ON_LINE_LOG, num)
		WriteOnLineCount()
		if os.date("%d") ~= today then
			today = os.date("%d")
			uplose = {}
			skynet.send("mysql", "lua", cmd.SQL_FLUSH_DAYHONOR)
			skynet.error(string.format("Flush dayhonor: time = %s", os.date()))
			if os.date("*t", os.time()).wday == 1 then
				skynet.send("mysql", "lua", cmd.SQL_FLUSH_WEEKHONOR)
				skynet.error(string.format("Flush weekhonor: time = %s", os.date()))
			end
			for k, v in pairs(all_player) do
				if not v.lock then
					pcall(skynet.send, v.address, "lua", cmd.EVENT_A_NEW_DAY)
				end
			end
			skynet.send("myredis", "lua", "a_new_day")
		end
	end)
end

local function Broadcast(mtype, ...)
	local msg
	if mtype then
		msg = MSG.pack(mtype, ...)
	else
		msg = ...
	end
	for k, v in pairs(all_player) do
		if not v.lock then
			pcall(skynet.send, v.address, "relay", msg)
		end
	end
end

local function GetBlockedPlayer()
	local result = skynet.call("mysql", "lua", cmd.SQL_GET_BLOCKED_PLAYER)
	if result and #result ~= 0 then
		for k, v in pairs(result) do
			local uid = tonumber(v[1])
			local endtime = tonumber(v[2])
			blocked_player[uid] = {uid = uid, endtime = endtime}
		end
	end
end

local function NotifySelfStateToFriend(uid, islogin, roomid)
	if all_player[uid] and all_player[uid].friends then
		local friends = {}
		if roomid then
			local selfstate = MSG.pack("friend_state", uid, islogin, roomid)
			table.insert(friends, selfstate)
		else
			local selfstate = MSG.pack("friend_state", uid, islogin)
			table.insert(friends, selfstate)
		end
		body = MSG.pack(cmd.SMSG_UPDATE_FRIEND_STATE, friends)
		for k, v in pairs(all_player[uid].friends) do
			if all_player[k] then
				SendTo(k, nil, body)
			end
		end
	end
end

local function GetFriends(uid)
	local result = skynet.call("mysql", "lua", cmd.SQL_GET_FRIENDS, uid)
	if all_player[uid] then
		if not all_player[uid].friends then
			all_player[uid].friends = {}
		end
		if result and #result ~= 0 then
			for k, v in pairs(result) do
				local id = tonumber(v[1])
				all_player[uid].friends[id] = id
			end
		end
	end
end

local function UpdateFriendState(uid, fids)
	local friends = {}
	local num = 0
	for k, v in pairs(fids) do
		if all_player[v] then
			num = num + 1
			if all_player[v].roomid then
				local friend = MSG.pack("friend_state", v, true, all_player[v].roomid)
				table.insert(friends, friend)
			else
				local friend = MSG.pack("friend_state", v, true, 0)
				table.insert(friends, friend)
			end
			if num >= 100 then
				break
			end
		end
	end
	SendTo(uid, cmd.SMSG_UPDATE_FRIEND_STATE, friends)
end

local function ChoiceDemandFriend(uid, demandfids)
	for k, v in pairs(demandfids) do
		if all_player[v] then
			SendTo(v, cmd.SMSG_CHOICE_FRIEND_DEMAND, uid)
		end
	end
end

command[cmd.CMSG_UPDATE_FRIEND] = function(body)
	local address, uid, msg = unpack(body)
	local fids = MSG.upack(cmd.CMSG_UPDATE_FRIEND, msg)
	UpdateFriendState(uid, fids)
end

command[cmd.CMSG_CHOICE_FRIEND_DEMAND] = function(body)
	local address, uid, demandfids = unpack(body)
	ChoiceDemandFriend(uid, demandfids)
end

command[cmd.EVENT_LOGIN] = function(body)
	local address, uid, sessionid, ptype = unpack(body)
	if server_close then
		skynet.ret(skynet.pack(errcode.SERVER_CLOSED))
	elseif blocked_player[uid] and blocked_player[uid].endtime > os.time() then
		skynet.ret(skynet.pack(errcode.PLAYER_BE_BLOCKED))
	elseif all_player[uid] then --断线重连支路
		if all_player[uid].lock then --此uid正处于登陆状态中
			skynet.ret(skynet.pack(errcode.LOGIN_AT_OTHER))
		else
			all_player[uid].lock = true -- 锁定登陆状态，即一个uid不能同时在不同地方登陆
			local ret
			local oldaddress
			local newaddress 
			local oldwatchdog = types.server_name["watchdog"][all_player[uid].ptype]
			local newwatchdog = types.server_name["watchdog"][ptype]
			if all_player[uid].ptype == ptype then
				ret, oldaddress, newaddress = skynet.call(oldwatchdog, "lua", cmd.EVENT_REDIRECT, sessionid, all_player[uid].sessionid)
			else
				oldaddress, oldagent = skynet.call(oldwatchdog, "lua", cmd.EVENT_CHANGE_AGENT, all_player[uid].sessionid, nil)
				newaddress, newagent = skynet.call(newwatchdog, "lua", cmd.EVENT_CHANGE_AGENT, sessionid, oldagent)
				local _, _ = skynet.call(oldwatchdog, "lua", cmd.EVENT_CHANGE_AGENT, all_player[uid].sessionid, newagent)
			end
			if all_player[uid] then
				pcall(skynet.send, all_player[uid].address, "lua", cmd.EVENT_RELOGIN, sessionid, newaddress, ptype)
			end
			skynet.ret(skynet.pack(errcode.LOGIN_AT_OTHER, all_player[uid].sessionid, oldaddress, all_player[uid].ptype))
			all_player[uid].sessionid = sessionid
			all_player[uid].ptype = ptype
			all_player[uid].lock = false
		end
	else -- 正常登陆支路
		skynet.ret(skynet.pack(0, sessionid, address, ptype, uplose))
		all_player[uid] = {uid = uid, address = address, sessionid = sessionid, roomid = nil, ptype = ptype}
	end
end

command[cmd.EVENT_SOME_ONE_ENTER] = function(body)
	local _, uid, roomid = unpack(body)
	if all_player[uid] then
		all_player[uid].roomid = roomid
	end
end

command[cmd.EVENT_SOME_ONE_QUIT] = function(body)
	local _, uid = unpack(body)
	if all_player[uid] then
		all_player[uid].roomid = nil
	end
end

command[cmd.EVENT_LOCK] = function(body)
	local _, uid, sessionid = unpack(body)
	if all_player[uid] then
		if all_player[uid].lock or all_player[uid].sessionid ~= sessionid then
			skynet.ret(skynet.pack(false))
		else
			all_player[uid].lock = true
			skynet.ret(skynet.pack(true))
		end
	else
		skynet.ret(skynet.pack(true))
	end
end

command[cmd.EVENT_UNLOCK] = function(body)
	local _, uid = unpack(body)
	if all_player[uid] then
		all_player[uid].lock = false
		skynet.ret(skynet.pack(true))
	else
		skynet.ret(skynet.pack(false))
	end
end

command[cmd.EVENT_LOGIN_OUT] = function(body)
	local _, uid, sessionid = unpack(body)
	if all_player[uid] then
		all_player[uid] = nil
	end
	skynet.ret(skynet.pack(true))
	if server_close then
		local close = true
		for k, v in pairs(all_player) do
			close = false
			break
		end
		if close then
			skynet.abort()
		end
	end
end

command[cmd.CMSG_CHAT_TO] = function(body)
	local address, playerid, suid, msg = unpack(body)
	SendTo(playerid, cmd.SMSG_CHAT_TO, suid, msg)
end

command[cmd.CMSG_BROADCAST] = function(body)
	local address, msg = unpack(body)
	msg = MSG.pack(cmd.SMSG_BROADCAST, 1, msg)
	for k, v in pairs(all_player) do
		SendTo(v.uid, nil, msg)
	end
end 

command[cmd.CMSG_GET_ONLINE] = function(body)
	local address, uid, girls = unpack(body)
	local onlines = {}
	local all_onlines = {}
	local online_infos = {}
	local num = 0

	for k, v in pairs(all_player) do --将在线人数的信息拷贝到一个临时表
		if k >= serverconf.robot.min and k <= serverconf.robot.max then
		else
			all_onlines[k] = v
		end
	end

	if #girls == 0 then -- 数据库里没有女玩家
		for k, v in pairs(all_onlines) do
			if uid == k then
				all_onlines[k] = nil
			elseif v.roomid then
				table.insert(onlines, k)	
				num = num + 1
				all_onlines[k] = nil
			end
			if num == 100 then
				break
			end
		end
	else
		for k, v in pairs(girls) do
			v[1] = tonumber(v[1])
			if v[1] == uid then
				girls[k] = nil
				all_onlines[v[1]] = nil
			elseif all_onlines[v[1]] then
				if all_onlines[v[1]].roomid then
					table.insert(onlines, v[1])
					num = num + 1
					all_onlines[v[1]] = nil
					girls[k] = nil
				end
				if num == 35 then -- 最多35个女的
					for k, v in pairs(girls) do
						all_onlines[tonumber(v[1])] = nil
					end
					break
				end
			end
		end
		if num < 35 then --如果在房间中的女的认识不够35，先选择在线单不在房间中的女的
			for k, v in pairs(girls) do
				v[1] = tonumber(v[1])
				if all_onlines[v[1]] then
					table.insert(onlines, v[1])
					num = num + 1
					all_onlines[v[1]] = nil -- 将该玩家从表中删除
					girls[k] = nil
				end
				if num == 35 then
					for k, v in pairs(girls) do
						all_onlines[tonumber(v[1])] = nil
					end
					break
				end
			end
		end
	end

	if num < 100 then
		for k, v in pairs(all_onlines) do
			if k == uid then
				all_onlines[k] = nil
			else
				table.insert(onlines, k)
				num = num + 1
			end
			if num == 100 then
				break
			end
		end
	end

	for k, v in ipairs(onlines) do
		local conf = skynet.call("mysql", "lua", cmd.SQL_GET_ONLINE_INFO, v)
		if conf and #conf ~= 0 then
			for i, j in pairs(conf) do
				local online_info = MSG.pack("online_info", v, j[1], j[2], tonumber(j[3]))
				table.insert(online_infos, online_info)
			end
		end
	end

--	for k, v in ipairs(online_infos) do
--		local uid, nickname, header, sex = MSG.upack("online_info", v)
--		print("nickname=", nickname, "header =", header, "sex=", sex, "uid=", uid)
--	end
--
	SendTo(uid, cmd.SMSG_GET_ONLINE, online_infos)
end

command[cmd.CMSG_GET_ONLINEINFO] = function(body)
	local address, uid, msg = unpack(body)
	local uid1 = MSG.upack(cmd.CMSG_GET_ONLINEINFO, msg)
	local roomid = 0
	local money = 0
	local score =  0
	if all_player[uid1] then
		local info = skynet.call("mysql", "lua", cmd.SQL_GET_ONLINE_GAMEINFO, uid1)
		if info and #info ~= 0 then
			for k, v in pairs(info) do
				if all_player[uid1].roomid then
					roomid = all_player[uid1].roomid
				end
				money = v[1]
				score = v[2]
			end
		end
	end
	SendTo(uid, cmd.SMSG_GET_ONLINEINFO, roomid, money, score)
end

command[cmd.EVENT_ADD_FRIEND] = function(body)
	local _, uid, fid = unpack(body)
	if all_player[uid] then
		if not all_player[uid].friends then
			all_player[uid].friends = {}
		end
		all_player[uid].friends[fid] = fid
	end
	if all_player[fid] then
		if not all_player[fid].friends then
			all_player[fid].friends = {}
		end
		all_player[fid].friends[uid] = uid
	end
end

command[cmd.EVENT_DEL_FRIEND] = function(body)
	local _, uid, fid = unpack(body)
	if all_player[uid] and all_player[uid].friends then
		all_player[uid].friends[fid] = nil
	end
	if all_player[fid] and all_player[fid].friends then
		all_player[fid].friends[uid] = nil
		SendTo(fid, cmd.SMSG_DEL_FRIEND, uid)
	end
end

command[cmd.EVENT_GET_PLAYER_GAMEINFO] = function(body)
	local _, uid = unpack(body)
	local ret = nil
	if all_player[uid] and not all_player[uid].lock then
		ret = skynet.call(all_player[uid].address, "lua", cmd.EVENT_GET_PLAYER_GAMEINFO)
	else
		local conf = skynet.call("mysql", "lua", cmd.SQL_GET_PLAYER_GAMEINFO, uid)
		if conf then
			ret = MSG.pack(cmd.SMSG_PLAYER_GAMEINFO, conf.uid, conf.money, conf.vip, conf.score, conf.wincount, conf.losecount, conf.drawcount, 0, 0, 0, conf.title, 0, tostring(0))
		end
	end
	skynet.ret(skynet.pack(ret))
end

command[cmd.ADMIN_BROADCAST] = function(body)
	local address, num, msg = unpack(body)
	if not num or num == 0 then
		print("admin broadcast num err", num)
	else
		msg = MSG.pack(cmd.SMSG_ADMIN_BROADCAST, num, msg)
		for k, v in pairs(all_player) do
			if v.address then
				SendTo(k, nil, msg)
			end
		end
	end
end

command[cmd.ADMIN_ADD_MONEY] = function(body)
	local address, addid, uid, money = unpack(body)
	local log = string.format("admin add money,player:%d, addid:%d, money:%d", uid, addid, money)
	skynet.send("CPLog", "lua", cmd.DAY_LOG, log)
	local succ = false
	if all_player[uid] and not all_player[uid].lock then
		succ = skynet.call(all_player[uid].address, "lua", cmd.EVENT_ADMIN_ADD_MONEY, addid, money)
	else
		local player = {uid = uid, addid = addid, money = money}
		local ret, retmoney, sqlpfid = skynet.call("mysql", "lua", cmd.SQL_ADMIN_ADD_MONEY, player)
		if ret then
			succ = true
			log = {uid = uid, 
				typeid = addid,
				addmoney = money, 
				assistid = 0,
				curmoney = retmoney + money,
				pfid = sqlpfid}
			skynet.send("mysql", "lua", cmd.SQL_MONEY_LOG, log)
		end
	end
	skynet.ret(skynet.pack(succ))
end

command[cmd.ADMIN_ADD_DTMONEY] = function(body)
	local address, addid, uid, dtmoney = unpack(body)
	local log = string.format("admin add cow, player:%d, addid:%d, dtmoney:%d", uid, addid, dtmoney)
	skynet.send("CPLog", "lua", cmd.DAY_LOG, log)
	local succ = false
	if all_player[uid] and not all_player[uid].lock then
		succ = skynet.call(all_player[uid].address, "lua", cmd.EVENT_ADMIN_ADD_DTMONEY, addid, dtmoney)
	else
		local player = {uid = uid, addid = addid, dtmoney = dtmoney}
		local ret, retdtmoney, sqlpfid = skynet.call("mysql", "lua", cmd.SQL_ADMIN_ADD_DTMONEY, player)
		if ret then
			succ = true
			log = { uid = uid, 
				typeid = addid,
				addcow = dtmoney,
				assistid = 0,
				curcow = retdtmoney + dtmoney,
				pfid = sqlpfid}
			skynet.send("mysql", "lua", cmd.SQL_DTMONEY_LOG, log)
		end
	end
	skynet.ret(skynet.pack(succ))
end

command[cmd.EVENT_SHOP] = function(body)
	local _, conf, insertid = unpack(body)
	if all_player[conf.uid] and not all_player[conf.uid].lock then
--		skynet.call(all_player[conf.uid].address, "lua", cmd.EVENT_SHOP, conf, insertid)
		skynet.send(all_player[conf.uid].address, "lua", cmd.EVENT_SHOP, conf, insertid)
	end
end

command[cmd.ADMIN_KICK_PLAYER] = function(body)
end

command[cmd.ADMIN_BLOCKED_PLAYER] = function(body)
	local address, uid, endtime = unpack(body)
	if endtime == 0 then
		if blocked_player[uid] then
			blocked_player[uid] = nil
		end
	else
		if all_player[uid] then
--			skynet.send(all_player[uid].address, "lua", cmd.EVENT_KICK, 1)
			pcall(skynet.send, all_player[uid].address, "lua", cmd.EVENT_KICK, 1)
		end
		blocked_player[uid] = {uid = uid, endtime = endtime}
	end
end

command[cmd.ADMIN_SERVER_CLOSE] = function(body)
	server_close = true
--	skynet.send("CPGame", "lua", "SERVER_CLOSE")
	skynet.send("BFGame", "lua", "SERVER_CLOSE")
--	Broadcast(cmd.SMSG_SERVER_CLOSE)
end

command[cmd.EVENT_SHUT_DOWN] = function(body)
	Broadcast(cmd.SMSG_SHUT_DOWN)
	for k, v in pairs(all_player) do
--		skynet.send(v.address, "lua", cmd.EVENT_SHUT_DOWN)
		pcall(skynet.send, v.address, "lua", cmd.EVENT_SHUT_DOWN)
	end
end

command[cmd.ADMIN_UPDATE_NOTICE] = function(body)
	local result = skynet.call("mysql", "lua", cmd.SQL_UPDATE_NOTICE)
	if result then
		Broadcast(nil, result)
	else
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, "Get notice error")
	end
	skynet.ret(skynet.pack(true))
end

command[cmd.ADMIN_CHANGE_SF_PWD] = function(body)
	local _, msg = unpack(body)
	msg.pwd = myclib.md5(msg.pwd)
	local succ = skynet.call("mysql", "lua", cmd.SQL_ADMIN_CHANGE_SF_PWD, msg)
	if all_player[msg.uid] and succ then
--		skynet.send(all_player[msg.uid].address, "lua", cmd.EVENT_ADMIN_CHANGE_SF_PWD, msg)
		pcall(skynet.send, all_player[msg.uid].address, "lua", cmd.EVENT_ADMIN_CHANGE_SF_PWD, msg)
	end
	skynet.ret(skynet.pack(succ))
end

command[cmd.EVENT_BROADCAST] = function(body)
	local _, msg = unpack(body)
	Broadcast(nil, msg)
end

local function send_weekreward(list)
	skynet.error(string.format("Send weeks ranking of the top 20 players: time = %s", os.date()))
	local i = 0
	for k, v in ipairs(list) do
		if k == 1 then
			i = 1
		elseif k == 2 then
			i = 2
		elseif k == 3 then
			i = 3
		elseif k >= 4 and k <= 8 then
			i = 4
		elseif k >= 9 and k <= 14 then
			i = 5
		elseif k >= 15 and k <= 20 then
			i = 6
		else
			return
		end
		local uid = v.uid
		if all_player[uid] and all_player[uid].pfid == serverconf.pfid.talker then
			i = i + 6	
		end
		local dtmoney = 0
		local sqlpfid = 0
		local id = task.id.ranklist
		local updtmoney = task.reward_money[id][i]
		local email = {uid = uid, id = id, type = 3, dtmoney = updtmoney}
		local result = skynet.call("mysql", "lua", cmd.SQL_GET_COWDUNG, uid)
		if result and #result ~= 0 then
			dtmoney	= result[1][1]
		end
		if all_player[uid] then
			sqlpfid = all_player[uid].sqlpfid
		else
			local ret = skynet.call("mysql", "lua", cmd.SQL_GET_PFID, uid)
			if ret then
				sqlpfid = ret
			end
		end
		local curcow = dtmoney + updtmoney
		local msg = {dtmoney = curcow, uid = uid}
		local log = {uid = uid, addcow = updtmoney, curcow = curcow, typeid = id, assistid = 0, pfid = sqlpfid}
		if v.weekhonor > 0 then
			skynet.send("mysql", "lua", cmd.SQL_UPDATE_COWDUNG, msg)
			SendTo(uid, cmd.SMSG_SEND_DTMONEY, uid, id, updtmoney)
			skynet.send("mysql", "lua", cmd.SQL_WRITE_SYSTEM_EMAIL, email)
			skynet.send("mysql", "lua", cmd.SQL_DTMONEY_LOG, log)
		end
	end
end

command[cmd.EVENT_SEND_WEEKREWARD] = function(body)
	local _, msg = unpack(body)
	send_weekreward(msg)
end

command[cmd.EVENT_ADD_MONEY_ANOTHER] = function(body)
	local _, uid, id, money, num = unpack(body)
	SendTo(uid, cmd.SMSG_ADD_MONEY, uid, id, money, num)
end

command[cmd.EVENT_REPLY_DEMAND_MONEY] = function(body)
	local _, uid, flag, fName, tName = unpack(body)
	SendTo(uid, cmd.SMSG_REPLY_DEMAND_MONEY, flag, fName, tName)
end

command[cmd.EVENT_UPDATE_UPLOSE] = function(body)
	local _, newuplose = unpack(body)
	uplose = newuplose
end

command[cmd.EVENT_GET_PFID] = function(body)
	local _, uid, sqlpfid = unpack(body)
	if all_player[uid] then
		all_player[uid].sqlpfid = tonumber(sqlpfid)
	end
end

skynet.register_protocol{
	name = "relay",
	id = 20,
	pack = function(...) return ... end,
	unpack = function(...) return ... end
}

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local mtype = body[1]
		body[1] = address
		local f = command[mtype]
		if f then
			f(body)
		else
			print("unknow message", mtype)
		end
	end)
	skynet.register(types.server_name["center"])
	GetBlockedPlayer()
	if not serverconf.TEST_MODEL then
		WriteOnLineCount()
	end
end)


