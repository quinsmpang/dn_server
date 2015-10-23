local skynet = require "skynet"
local types = require "types"
local cmd = require "cmd"
local casino = require "poker"
local string = string
local table = table
local pairs = pairs
local client, sessionid, addr, ptype = ...
local errcode = require"errorcode"
local serverconf = require"serverconf"
local task = require"taskconf"
local myclib = require"myclib"
local timer = require"timer"
local MSG = require"gamepacket"
local hearttimer = timer.new()
local logintime = 0
local cowprice = 0
local wishing_well = {isbet = false, sign = 0}

math.randomseed(os.time())

local self = {}
local roomconf = {}
local connected = true
local command = {}
local admin_add_money = {}
--local print = function(...) end
local kickid = 0
local tools = {}
local cowgoods = {}
local curstate = commected
local minmoney_fastenter = 600

local agent_state = {
	connected			= 1,
	login_in			= 2,
	login_succ			= 3,
	enter_room			= 4,
	at_room				= 5,
	sit_down			= 6,
	be_seated			= 7,
	stand_up			= 8,
	quit_room			= 9,
	login_out			= 10,
	disconnect			= 11
}

local cur_state = agent_state.connected

local function ChangeState(state)
	print("change state &&&&&&&&&&&&&&", state)
	cur_state = state
end

local function WriteLog(logtype, msg)
	local body
	if self.uid then
		body = string.format("player %d %s", self.uid, msg)
	else
		body = string.format("Didn't login player,%s", msg)
	end
	skynet.send("CPLog", "lua", logtype, body)
end

local function MoneyLog(logtype, money, curmoney, assistid) --记录金币变化
	if logtype == serverconf.money_log.new_player then
		money = self.money
	end
	msg = {
		uid			= self.uid,
		typeid		= logtype,
		addmoney	= money,
		curmoney	= curmoney
		}
	if assistid then
		msg.assistid = assistid
	else
		msg.assistid = 0
	end
	msg.pfid = self.sqlpfid
--	if logtype == serverconf.money_log.ticket or logtype == serverconf.money_log.table_win then
		self.moneychange = self.moneychange + msg.addmoney
--	end
	skynet.send("mysql", "lua", cmd.SQL_MONEY_LOG, msg)
end

local function DtmoneyLog(logtype, dtmoney, curdtmoney, assistid) --记录牛粪变化
	msg = {
		uid = self.uid,	
		typeid = logtype,
		addcow = math.floor(dtmoney) / 10,
		curcow = math.floor(curdtmoney) / 10
	}
	if assistid then
		msg.assistid = assistid
	else
		msg.assistid = 0
	end
	msg.pfid = self.sqlpfid
	skynet.send("mysql", "lua", cmd.SQL_DTMONEY_LOG, msg)
end

local function GetServerName(target)
	if target == "game" then
		if roomconf and roomconf.gametype then
			return types.server_name[target][roomconf.gametype]
		end
	elseif target == "watchdog" then
		return types.server_name[target][ptype]
	else
		return types.server_name[target]
	end
	return nil
end

local function Send(target, targetid, msg_type, ...)
	if target == "player" then
		local msg
		if msg_type then
			msg = MSG.pack(msg_type, ...)
		else
			msg = ...
		end
		--if targetid == self.uid then
		if targetid == self.uid or msg_type==cmd.SMSG_LOGIN_FAILD then
			if connected then
				if ptype == "W" then
					skynet.send(client, 111, msg)
				else 
					skynet.send(client, 3, msg)
				end
			end
		else
			if self.roomid then
				skynet.send("CPRoom", "lua", cmd.EVENT_SEND_TO, self.roomid, targetid, msg)
			end
		end
	else
		local s_name = GetServerName(target)
		if s_name then
			if target == "game" then
				skynet.send(s_name, "game", msg_type, ...)
			else
				skynet.send(s_name, "lua", msg_type, ...)
			end
		end
	end
end


local function Call(target, targetid, msg_type, ...)
	local s_name = GetServerName(target)
	if s_name then
		if target == "game" then
			return skynet.call(s_name, "game", msg_type, ...) -- call时进程挂起，此时可执行其他进程
		else
			return skynet.call(s_name, "lua", msg_type, ...)
		end
	else
		print("have no this server", target)
	end
end

local function BlockCall(target, targetid, msg_type, ...)
	local s_name = GetServerName(target)
	if s_name then
		if target == "game" then
			return skynet.blockcall(s_name, "game", msg_type, ...) --blockcall时需等待进程完成，才能执行其他进程
		else
			return skynet.blockcall(s_name, "lua", msg_type, ...)
		end
	else
		print("have no this server", target)
	end
end

local function GetIP()
	if addr then 
		return string.match(addr, "(.*)%:")
	else
		return nil
	end
end

local function GetTopList(topid) --获取排行榜内容
	if self.uid then
		local list = Call("redis", nil, "get_top_list", self.uid, topid)
		local pack_list = {}
		for k, v in pairs(list) do
			if #pack_list >= 50 then
				break
			end
			local plr_info = MSG.pack("player_info", v.uid, v.money, v.score, v.info, v.qq_vip, v.vip)
			table.insert(pack_list, plr_info)
		end
		Send("player", self.uid, cmd.SMSG_TOP_LIST, topid, pack_list)
	end
end

local function GetSelfVip()
	if self.viptime ~= 0 and self.viptime < os.time() then
		self.vip = 0
		self.viptime = 0
		for k, v in pairs(tools) do
			if v.kind == 1 and v.endtime > os.time() then
				if self.vip < v.vip then
					self.vip = v.vip
					self.viptime = v.endtime
				end
			end
		end
	end
	return self.vip
end

local function GetSelfGameConf()
	local result = Call("mysql", nil, cmd.SQL_GET_PLAYERCONF, self.uid)
	if result ~= nil and #result ~= 0 then
		self.money, self.score= tonumber(result[1][1]), tonumber(result[1][2])
		self.wincount, self.losecount = tonumber(result[1][3]), tonumber(result[1][4])
		self.drawcount, self.monthwin = tonumber(result[1][5]), tonumber(result[1][6])
		self.monthlose, self.monthdraw = tonumber(result[1][7]), tonumber(result[1][8])
		self.daywin, self.daylose = tonumber(result[1][9]), tonumber(result[1][10])
		self.daydraw, self.date = tonumber(result[1][11]), tonumber(result[1][12])
		self.qq_vip, self.besttype = tonumber(result[1][13]), tonumber(result[1][14])
		self.dtmoney, self.dayhonor = 10 * tonumber(result[1][15]), tonumber(result[1][16])
		self.weekhonor, self.gametime = tonumber(result[1][17]), tonumber(result[1][18])
		self.redpackettime = tonumber(result[1][19])
		self.moneychange = 0
		self.starttime = 0
		self.redstarttime = 0
		if not self.date then
			self.date = 0
		end
		if self.date ~= tonumber(os.date("%Y%m%d")) then
			self.dateflag = true -- 使得玩家登陆不做任何操作就退出游戏，也会执行updatetodb函数
		end
		if not self.weekhonor then
			self.weekhonor = 0
		end
		if not self.dayhonor then
			self.dayhonor = 0
		end
		if not self.besttype then
			self.besttype = 0
		end
		local msg = {uid = self.uid, dtmoney = math.floor(self.dtmoney) / 10} -- 解决数据库dtmoney值多个小数位问题
		skynet.send("mysql", "lua", cmd.SQL_UPDATE_COWDUNG, msg)
		if math.floor(self.date / 100) ~= tonumber(os.date("%Y%m")) then --不同月登录清零
			self.daywin = 0
			self.daylose = 0
			self.daydraw = 0
			self.gametime = 0
			self.redpackettime = 0
			self.monthwin = 0
			self.monthlose = 0
			self.monthdraw = 0
			self.date = tonumber(os.date("%Y%m%d"))
		elseif self.date ~= tonumber(os.date("%Y%m%d")) then -- 不同日登录清零 
			self.daywin = 0
			self.daylose = 0
			self.daydraw = 0
			self.gametime = 0
			self.redpackettime = 0
			self.date = tonumber(os.date("%Y%m%d"))
		end
		self.upmoney, self.upscore = 0, 0
		self.updtmoney = 0
		self.upwincount, self.uplosecount = 0, 0
		self.updrawcount = 0
		return true
	else
		print("get selfconf error")
		return false
	end
end

local function UpdatePlayNum() --更新对局数到数据库
	if roomconf.roomtype and self.daywinnum and self.daylosenum and self.daydrawnum and self.dayscore and self.moneychange then
		local msg = {uid = self.uid, ttype = roomconf.roomtype, daywinnum = self.daywinnum, daylosenum = self.daylosenum, daydrawnum = self.daydrawnum, dayscore = self.dayscore, date = tonumber(os.date("%Y%m%d")), daymoney = self.moneychange, pfid = self.sqlpfid}
		--[[
		if msg.ttype == nil then
			skynet.error(string.format("roomtype is nil: uid = %d, money = %d, roomid = %d, roomtype = %d, time = %d", self.uid, self.money, self.roomid, roomconf.roomtype, tonumber(os.time())))
		end
		--]]
		Send("mysql", nil, cmd.SQL_UPDATE_PLAYNUM, msg)
	end
end

local function UpdateInfo() --更新个人信息到redis
	if self.uid and self.money and self.qq_vip and self.score and self.info and self.dayhonor and self.weekhonor and self.vip then
		local player_info = {
			uid = self.uid,
			money = self.money,
			score = self.score,
			dayhonor = self.dayhonor,
			weekhonor = self.weekhonor,
			info = self.info,
			qq_vip = self.qq_vip,
			vip = GetSelfVip(),
			time = os.time()}
		Send("redis", nil, "update_info", player_info)
	end
end

local function GetHonorList() --获取荣誉排行榜内容
	local player_info = {
		uid = self.uid,
		money = self.money,
		score = self.score,
		dayhonor = self.dayhonor,
		weekhonor = self.weekhonor,
		info = self.info,
		qq_vip = self.qq_vip,
		vip = GetSelfVip(),
		time = os.time()}
	if self.uid then
		local listd, listw = Call("redis", nil, "get_honor_list", self.uid, player_info)
		local packd = {}
		local packw = {}
		for k, v in ipairs(listd) do
			if v.dayhonor > 0 then
				local plr_info = MSG.pack("player_info_honor", v.info, v.dayhonor)
				table.insert(packd, plr_info)
			end
		end

		local i = 1
		local playerweeksort = 0
		for k, v in ipairs(listw) do
			if v.weekhonor > 0 then
				local plr_info = MSG.pack("player_info_honor", v.info, v.weekhonor)
				table.insert(packw, plr_info)
			if self.uid == v.uid then
				 playerweeksort = i
			end
			i = i + 1
			end
		end

		--[[
		if self.uid == 1491 then
			skynet.error("11111111111111111111111111111111111111111")
			for k, v in ipairs(packw) do
				local info, weekhonor = MSG.upack("player_info_honor", v)
				skynet.error(string.format("info=%s, weekhonor=%d, self.uid=%d", info, weekhonor, self.uid))
			end
		end
		--]]
		Send("player", self.uid, cmd.SMSG_HONOR_LIST, playerweeksort, self.dayhonor, self.weekhonor, packd, packw)
	end
end

local function Broadcast(toself, msg_type, ...)
	if self.roomid == nil then
		return
	end
	local msg
	if msg_type then
		msg = MSG.pack(msg_type, ...)
	else
		msg = ...
	end
	local uid = 0
	if not toself then
		uid = self.uid
	end
	Send("room", nil, cmd.EVENT_ROOM_BROADCAST, self.roomid, uid, msg)
end

local function BroadcastEvent(event, togame, ...) 
	if self.roomid then
		Send("room", nil, cmd.EVENT_ROOM_EVENT, self.roomid, self.uid, event, self.uid)
		if togame then
			Send("game", nil, event, ...)
		end
	end
end

local function UpdateToDB()
	if self.login and self.upmoney then
		if self.upmoney ~= 0 or self.upscore ~= 0 or self.upwincount ~= 0 or self.updtmoney ~= 0 or self.uplosecount ~= 0 or self.updrawcount ~= 0 or self.dateflag then
			local sql = {upmoney = self.upmoney, upscore = self.upscore, upwincount = self.upwincount,
				uplosecount = self.uplosecount, updrawcount = self.updrawcount, uid = self.uid, 
				monthwin = self.monthwin, monthlose = self.monthlose,
				monthdraw = self.monthdraw, daywin = self.daywin,
				daylose = self.daylose, daydraw = self.daydraw,
				date = self.date, besttype = self.besttype,
				updtmoney = (math.floor(self.updtmoney) / 10),
				dayhonor = self.dayhonor, weekhonor = self.weekhonor}
			Send("mysql", nil, cmd.SQL_UPDATE_PLAYERCONF, sql)
			self.upmoney = 0
			self.updtmoney = 0
			self.upscore = 0
			self.upwincount = 0
			self.uplosecount = 0
			self.updrawcount = 0
		end
	end
end

local function	UpdateSafeBoxToDB()
	if self.safebox then
		Send("mysql", nil, cmd.SQL_UPDATE_SAFE_BOX, self.safebox)
		self.safebox.upmoney = 0
	end
end

local function QuitSucc()
	if self.roomid then
		if self.seatid and not self.scratchflag and (roomconf.roomtype == 1 or roomconf.roomtype == 2) then
			self.gametime = os.time() - self.starttime + self.gametime
		end
		local ret = Call("room", nil, cmd.CMSG_QUIT_ROOM, self.uid, self.roomid)
		if ret == 0 then
			ChangeState(agent_state.login_succ)
			Send("player", self.uid, cmd.SMSG_SOMEONE_QUIT, self.uid)
			Send("center", nil, cmd.EVENT_SOME_ONE_QUIT, self.uid, self.roomid)
			WriteLog(cmd.DAY_LOG, string.format("quit from room %d", self.roomid))
		end
		self.seatid = nil
		self.roomid = nil
		self.starttime = 0
		roomconf = {}
	end
end

local function CheckGameTime()
	local time = 0
	local taskid = task.id.scratch
	for i = 0, 5 do
		if self.scratch == i then
			if self.gametime < task.reward_money[task.id.scratch][i + 1] then
				time = task.reward_money[taskid][i + 1] - self.gametime
			else
				self.scratchflag = true	
				self.gametime = task.reward_money[taskid][i + 1]
				time = 0
			end
			break
		end
	end

	if self.scratch == 6 then
		self.gametime = task.reward_money[taskid][6]
		time = -1
	end

	return time
end

local function CheckRedPacketTime()
	local time = 0
	local id = task.id.redpacket
	if self.redpackettime < task.reward_money[id][2] then
		time = task.reward_money[id][2] - self.redpackettime
	else
		self.redpackettime = task.reward_money[id][2]
	end
	if self.redpacket >= task.count[id] then
		self.redpackettime = task.reward_money[id][2]
		time = -1
	end
	
	return time
end

local function Exit()
	if self.lock then
--		skynet.error(string.format("exit faild: uid = %d, money = %d, time = %d", self.uid, self.money, tonumber(os.time())))
		return
	end
	self.lock = true
	ChangeState(agent_state.disconnect)
	UpdateToDB()
	Send("center", nil, cmd.EVENT_UPDATE_UPLOSE, self.uplose)
	local ret = true 
	if self.uid then
		if Call("center", nil, cmd.EVENT_LOCK, self.uid, sessionid) then
			self.login = false
			if self.roomid then
				if BlockCall("game", nil, cmd.CMSG_TRY_QUIT) == 0 then
					QuitSucc()
				else
--					skynet.error(string.format("try quit faild: uid = %d, money = %d, roomid = %d, roomtype = %d, time = %d", self.uid, self.money, self.roomid, roomconf.roomtype, tonumber(os.time())))
					self.login = true
					local res = Call("center", nil, cmd.EVENT_UNLOCK, self.uid)
					ret = false
				end
			end
			if ret then
				UpdateSafeBoxToDB()
				Send("mysql", nil, cmd.SQL_UPDATE_TOOLS, tools)
				if self.gametime then
					CheckGameTime()
					local msg = {uid = self.uid, gametime = self.gametime}
					Send("mysql", nil, cmd.SQL_UPDATE_GAMETIME, msg)
				end
				if self.redpackettime then
					if self.redstarttime ~= 0 then
						self.redpackettime = self.redpackettime + tonumber(os.time()) - self.redstarttime
					end
					if self.redpackettime > task.reward_money[task.id.redpacket][2] then
						self.redpackettime = task.reward_money[task.id.redpacket][2]
					end
					local msg = {uid = self.uid, redpackettime = self.redpackettime}
					Send("mysql", nil, cmd.SQL_UPDATE_REDPACKETTIME, msg)
				end
				ret = BlockCall("center", nil, cmd.EVENT_LOGIN_OUT, self.uid, sessionid)
				UpdateInfo()
			end
		else
			ret = false
		end
	end
	if ret and not self.login then
		if self.uid then
			Send("mysql", nil, cmd.SQL_LOGIN_OUT, self.uid)
		end
		Send("watchdog", nil, cmd.EVENT_AGENT_CLOSE, sessionid)
		skynet.timeout(5, function()
			skynet.kill(client)
		end)
		skynet.exit()
		print("agent exit")
	end
	self.lock = false
end

local function LoseMoney(losemoney, loseid, assistid)
	if loseid == serverconf.money_log.table_win or loseid == serverconf.money_log.ticket then
		if not self.uplose[self.uid] then
			self.uplose[self.uid] = {}
		end
		if not self.uplose[self.uid][self.roomid] then
			self.uplose[self.uid][self.roomid] = {}
			self.uplose[self.uid][self.roomid].lose = 0
		end
		self.uplose[self.uid][self.roomid].lose = self.uplose[self.uid][self.roomid].lose - losemoney
		self.sumlose = self.sumlose - losemoney
	end
	if losemoney > self.money then
		print("lose money error, real money:", self.money, "lose money:", losemoney)
	else
		self.money = self.money - losemoney
		self.upmoney = self.upmoney - losemoney
		if self.money > minmoney_fastenter then
			self.redpackettime = 0
			self.redstarttime = 0
		end
		MoneyLog(loseid, -losemoney, self.money, assistid)
	end
end

local function AddMoney(money, addid, assistid)
	if addid == serverconf.money_log.table_win or addid == serverconf.money_log.ticket then
		if not self.uplose[self.uid] then
			self.uplose[self.uid] = {}
		end
		if not self.uplose[self.uid][self.roomid] then
			self.uplose[self.uid][self.roomid] = {}
			self.uplose[self.uid][self.roomid].lose = 0
		end
		self.uplose[self.uid][self.roomid].lose = self.uplose[self.uid][self.roomid].lose + money
		self.sumlose = self.sumlose + money
	end
	self.money = self.money + money
	self.upmoney = self.upmoney + money
	if self.money > minmoney_fastenter then
		self.redpackettime = 0
		self.redstarttime = 0
	end
	MoneyLog(addid, money, self.money, assistid)
end

local function LoseDtmoney(losedtmoney, loseid, assistid)
	if losedtmoney > self.dtmoney then
		print("lose dtmoney error, real dtmoney:", self.dtmoney, "lose dtmoney:", losedtmoney)
	else
		self.dtmoney = self.dtmoney - losedtmoney
		self.updtmoney = self.updtmoney - losedtmoney
		DtmoneyLog(loseid, -losedtmoney, self.dtmoney, assistid)
	end
end

local function AddDtmoney(dtmoney, addid, assistid)
	self.dtmoney = self.dtmoney + dtmoney
	self.updtmoney = self.updtmoney + dtmoney
	DtmoneyLog(addid, dtmoney, self.dtmoney, assistid)
end

local function DealAdminAddMoney()
	if not self.lockmoney and admin_add_money and #admin_add_money ~= 0 then
		for k, v in pairs(admin_add_money) do
			local money = -v.money
			if moeny > self.money then
				money = self.money
			end
			LoseMoney(money, v.addid)
			if self.roomid then
				Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, v.addid, -money)
			else
				Send("player", self.uid, cmd.SMSG_ADD_MONEY, self.uid, v.addid, -money)
			end
		end
	end
end

local function BreakProtect()
	local id = task.id.protect
	local money = task.reward_money[id]
--	if self.money >= money or not roomconf or roomconf.minmoney > money then
	if self.money >= money or not roomconf then
		return false
	else
		money = money - self.money
	end
	if self.safebox then
		if self.safebox.money + self.money > roomconf.minmoney then
			return false
		end
	end
	local msg = {uid = self.uid, taskid = id, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
	if ret and not self.lockmoney and not self.taskmoneylock then
		local money = task.reward_money[id]
		AddMoney(money, id)
		self.protect = self.protect + 1
		Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, id, money , task.count[task.id.protect] - sign)
		return true
	else
		return false
	end
end

local function GetPlayNum(roomtype)
	local msg = {uid = self.uid, ttype = roomtype, date = tonumber(os.date("%Y%m%d"))}
	local result = Call("mysql", nil, cmd.SQL_GET_PLAYNUM, msg)
	if result and #result ~= 0 then
		self.daywinnum = tonumber(result[1][1])
		self.daylosenum = tonumber(result[1][2])
		self.daydrawnum = tonumber(result[1][3])
		self.dayscore = tonumber(result[1][4])
	else
		self.daywinnum = 0
		self.daylosenum = 0
		self.daydrawnum = 0
		self.dayscore = 0
	end
	local dayplaynum = self.daywinnum + self.daylosenum + self.daydrawnum
	return dayplaynum
end

local function EnterResp(resp)
	if 0 ~= resp and -1 ~= resp then
		ChangeState(agent_state.login_succ)
		Send("player", self.uid, cmd.SMSG_ENTER_ROOM_FAILD, resp)
		WriteLog(cmd.DEBUG_LOG, string.format("enter room failed, errorid:%d", resp))
	else
		if self.seatid then
			ChangeState(agent_state.be_seated)
		else
			ChangeState(agent_state.at_room)
		end

		if roomconf.roomtype == 1 or roomconf.roomtype == 2 then
			local time = CheckGameTime()
			Send("player", self.uid, cmd.SMSG_SCRATCH_TIME, time)
		end
		GetPlayNum(roomconf.roomtype)
		Send("center", nil, cmd.EVENT_SOME_ONE_ENTER, self.uid, self.roomid)
		Send("game", nil, cmd.EVENT_SOME_ONE_ENTER)
		WriteLog(cmd.DAY_LOG, string.format("enter room %d", self.roomid))
	end
end 

local function DemandWindown()
	local msg = {uid = self.uid, taskid = task.id.friend_send, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
	if self.protect >= task.count[task.id.protect] and self.demand < task.count[task.id.friend_send] then
		Send("player", self.uid, cmd.SMSG_DEMAND_MONEY_WINDOW, (task.count[task.id.friend_send] - self.demand))
		self.demand = self.demand + 1
	end
end

local function RedPacketTask()
	local taskid = task.id.redpacket
	local time = CheckRedPacketTime()
	self.redstarttime = tonumber(os.time())
	if self.protect >= task.count[task.id.protect] and self.money < minmoney_fastenter and self.redpacket < task.count[taskid] then
		Send("player", self.uid, cmd.SMSG_RED_PACKET, time)
	end
end

local function SitResp(ret, seatid) 
	if 0 ~= ret then
		ChangeState(agent_state.at_room)
		Send("player", self.uid,  cmd.SMSG_SIT_FAILD, ret)
		WriteLog(cmd.DEBUG_LOG, string.format("sit failed, errorid:%d", ret))
		if ret == errcode.HAVE_NO_ENOUGH_MONEY and roomconf.roomtype == 1 then
			DemandWindown()	
		end
	else
		if roomconf.roomtype == 1 or roomconf.roomtype == 2 then
			self.starttime = os.time()
		end
		ChangeState(agent_state.be_seated)
		self.seatid = seatid
		Broadcast(true, cmd.SMSG_UP_GAME_DATA, self.uid, self.money, self.score, self.vip)
		Send("game", nil, cmd.EVENT_SOME_ONE_SIT)
		Send("redis", nil, "record_player_num", self.uid, roomconf.roomtype)
		WriteLog(cmd.DAY_LOG, string.format("sit at %d", self.seatid))
	end
end

local function StandSucc()
	if self.seatid then
		local ret = Call("room", nil, cmd.CMSG_STAND, self.uid, self.roomid, self.seatid, true)
		ChangeState(agent_state.at_room)
		if not self.scratchflag and (roomconf.roomtype == 1 or roomconf.roomtype == 2) then
			self.gametime = self.gametime + os.time() - self.starttime
		end
		self.starttime = 0
		self.seatid = nil
	end
end

local function StandResp()
	ChangeState(agent_state.stand_up)
	self.lockmoney = true
	local losemoney, cardsid = BlockCall("game", nil, cmd.EVENT_SOME_ONE_STAND, self.money)
	if losemoney ~= 0 then
		LoseMoney(losemoney, serverconf.money_log.escape, cardsid)
		local winlog = {uid = self.uid, roomid = self.roomid, escape = 1, 
			leftmoney = self.money, winmoney = -losemoney}
		Send("mysql", nil, cmd.SQL_WIN_LOG, winlog)
	end
	self.lockmoney = false
	StandSucc()
end

local function StandFailed(errcode)
	ChangeState(agent_state.be_seated)
	Send("player", self.uid, cmd.SMSG_STAND_FAILD, errcode)
	WriteLog(cmd.DEBUG_LOG, string.format("stand failed, errorid:%d", errcode))
end

local function PlayerTryStand()
	ChangeState(agent_state.stand_up)
	local ret = BlockCall("game", nil, cmd.CMSG_TRY_STAND)
	if ret == 0 then
		StandSucc()
	else
		StandFailed(ret)
	end
	return ret
end

local function QuitResp()
	if self.roomid then
		ChangeState(agent_state.quit_room)
		self.lockmoney = true
		local losemoney, cardsid = BlockCall("game", nil, cmd.EVENT_SOME_ONE_QUIT, self.money)
		if losemoney ~= 0 then
			LoseMoney(losemoney, serverconf.money_log.escape, cardsid)
			local winlog = {uid = self.uid, roomid = self.roomid, escape = 1, 
			leftmoney = self.money, winmoney = -losemoney}
			Send("mysql", nil, cmd.SQL_WIN_LOG, winlog)
		end
		self.lockmoney = false
		QuitSucc()
		return true
	else
		return false
	end
end

local function PlayerTryQuit()
	local ret = BlockCall("game", nil, cmd.CMSG_TRY_QUIT)
	if ret == 0 then
		QuitSucc()
	else
		if self.seatid then
			ChangeState(agent_state.be_seated)
		else
			ChangeState(agent_state.at_room)
		end
		Send("player", self.uid, cmd.SMSG_QUIT_FAILD, tonumber(ret))
		WriteLog(cmd.DEBUG_LOG, string.format("quit failed, errorid:%d", ret))
	end
	return ret
end

local TryQuit = function(body)
	if self.lock then
		return
	end
	ChangeState(agent_state.quit_room)
	if self.roomid then
		local ret = PlayerTryQuit()
		self.lock = false
		if ret == 0 then
			return true
		else
			return false
		end
	end
end

local function BeKicked()
	if kickid == 1 then
		if self.roomid then
			TryQuit()
		end
		WriteLog(cmd.DAY_LOG, "be kicked by admin")
		connected = false
		Exit()
	end
end

local function HaveDoubleScoreCard()
	for k, v in pairs(tools) do
		if v.kind == 5 and v.endtime > os.time() then
			return true
		end
	end
	return false
end

local function GetFaceCost(faceid) --发送表情
	local cost = 0
	if GetSelfVip() ~= 0 or (self.free_face_time and self.free_face_time >= tonumber(os.time())) then
		cost = 0
	elseif roomconf.basebet then
		cost = math.floor(roomconf.basebet * serverconf.face_cost)
	end
	return cost
end

local function GetPtypeNum(taskptype)
	local ptypenum
	local msg = {uid = self.uid, ptype = taskptype, date = tonumber(os.date("%Y%m%d"))}
	local result = Call("mysql", nil, cmd.SQL_GET_PTYPENUM, msg)
	if result and #result ~= 0 then
		ptypenum = result[1][1]
	else
		ptypenum = 0
	end
	return ptypenum
end

local function CurTaskconf() --部分任务数据
	local needsendtask = {
		[task.id.qq_vip]		= true,
		[task.id.qq_year_vip]	= true,
		[task.id.qq_vip_course] = true,
		[task.id.protect]		= true,
		[task.id.learn_course]	= true,
		[task.id.microblog]		= true,
		[task.id.day_login]		= true,
		[task.id.friend_send]	= true,
		[task.id.scratch]		= true,
		[task.id.redpacket]		= true,

		[task.id.play1_20]		= true,
		[task.id.play1_40]		= true,
		[task.id.play1_60]		= true,
		[task.id.play2_20]		= true,
		[task.id.play2_35]		= true,
		[task.id.play2_50]		= true,
		[task.id.play3_15]		= true,
		[task.id.play3_30]		= true,
		[task.id.play3_50]		= true,
		[task.id.play4_15]		= true,
		[task.id.play4_30]		= true,
		[task.id.play4_50]		= true,

		[task.id.ptype_0]		= true,
		[task.id.ptype_1]		= true,
		[task.id.ptype_2]		= true,
		[task.id.ptype_3]		= true,
		[task.id.ptype_4]		= true,
		[task.id.ptype_5]		= true,
		[task.id.ptype_6]		= true,
		[task.id.ptype_7]		= true,
		[task.id.ptype_8]		= true,
		[task.id.ptype_9]		= true,
		[task.id.ptype_10]		= true,
		[task.id.ptype_11]		= true,
		[task.id.ptype_12]		= true,
		[task.id.ptype_13]		= true,
		[task.id.ptype_14]		= true,
	}
	local msg = {uid = self.uid}
	local result = Call("mysql", nil, cmd.SQL_GET_TASKCONF, msg)
	if not result[task.id.protect] then
		self.protect = 0
	else
		self.protect = result[task.id.protect].num
	end

	if not result[task.id.friend_send] then
		self.demand = 0
	else
		self.demand = result[task.id.friend_send].num
	end

	if not result[task.id.redpacket] then
		self.redpacket = 0
	else
		self.redpacket = result[task.id.redpacket].num
	end

	if not result[task.id.scratch] then
		self.scratch = 0
	else
		self.scratch = result[task.id.scratch].num
	end
	local taskconfs = {}
	local m = 0
	for k, v in pairs(needsendtask) do
		local j = 0
		local conf = {taskid = k, complete = 0, curstate = true, money = 0, cow = 0, playpoint = 0, rtype = 0, dayplaynum = 0}
		if result[k] then
			conf.complete = result[k].num
			if task.count[k] <= conf.complete then
				conf.curstate = false
			end
		end
		if conf.curstate then
			if k == task.id.qq_vip then
				if not self.qq_vip or self.qq_vip == 0 then
					conf.curstate = false
				end
			elseif k == task.id.qq_year_vip then
				if not self.qq_vip or self.qq_vip <= 10 then
					conf.curstate = false
				end
			end
		end
		if k >= task.id.play1_20 and k <= task.id.play4_50 then
			if self.pfid == serverconf.pfid.talker then
				m = 3
			end
		end
		if k == task.id.play1_20 or k == task.id.play1_40 or k == task.id.play1_60 then
			conf.rtype = 1
			conf.money = task.reward_money[k][1 + m]
			conf.cow = task.reward_money[k][2 + m]
			conf.playpoint = task.reward_money[k][3 + m]
		elseif  k == task.id.play2_20 or k == task.id.play2_35 or k == task.id.play2_50 then
			conf.rtype = 2
			conf.money = task.reward_money[k][1 + m]
			conf.cow = task.reward_money[k][2 + m]
			conf.playpoint = task.reward_money[k][3 + m]
		elseif k == task.id.play3_15 or k == task.id.play3_30 or k == task.id.play3_50 then
			conf.rtype = 3
			conf.money = task.reward_money[k][1 + m]
			conf.cow = task.reward_money[k][2 + m]
			conf.playpoint = task.reward_money[k][3 + m]
		elseif k == task.id.play4_15 or k == task.id.play4_30 or k == task.id.play4_50 then
			conf.rtype = 4
			conf.money = task.reward_money[k][1 + m]
			conf.cow = task.reward_money[k][2 + m]
			conf.playpoint = task.reward_money[k][3 + m]
		end
			conf.dayplaynum = GetPlayNum(conf.rtype)

		if k >= task.id.ptype_0 and k <= task.id.ptype_14 then
			if self.pfid == serverconf.pfid.talker then
				m = 2
			end
			conf.rtype = tonumber(k - 1300) --任务id范围1300 - 1314
			conf.cow = task.reward_money[k][1 + m] --某图标点亮后的奖励
			conf.playpoint = task.reward_money[k][2 + m]
			conf.dayplaynum = GetPtypeNum(conf.rtype) --某牌型完成次数
		end

		
		local p = MSG.pack("task", conf.taskid, conf.complete, conf.curstate, conf.money, conf.cow, conf.playpoint, conf.rtype, conf.dayplaynum)
--		print("taskid=", conf.taskid, "complete=", conf.complete, "money=", conf.money, "cow=", conf.cow, "playpoint=", conf.playpoint, "rtype=", conf.rtype, "dayplaynum=", conf.dayplaynum)
		table.insert(taskconfs, p)
	end
	local dayplay = self.daywin + self.daylose + self.daydraw
	Send("player", self.uid, cmd.SMSG_TASKCONF, self.daywin, dayplay, taskconfs)
end

local function UpdateToolsConf(today_first_login)
	local cardmoney = 0
	local vipmoney = 0
	local needup = false
	local conf = Call("shop", nil, cmd.EVENT_TOOLS_CONF)
	for k, v in pairs(tools) do
		if v.status == 1 or v.status == 0 then -- 0 表示道具未使用, 1 表示使用中 2 表示使用完成
			if conf[v.typeid] then
				v.kind = conf[v.typeid].typeid
			end
			if not conf[v.typeid] then
				v.status = 2
			elseif v.kind == 1 then -- vip
				v.endtime = v.stime + conf[v.typeid].udays * 24*60*60
				if v.endtime > os.time() then
					if v.stime <= os.time() and today_first_login then
						vipmoney = vipmoney+ conf[v.typeid].dmoney
						AddMoney(conf[v.typeid].dmoney, v.typeid)
						local m = {uid = self.uid, id = v.typeid, type = 1, money = conf[v.typeid].dmoney}
						Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
					end
					v.vip = conf[v.typeid].vip
					if self.vip < v.vip then
						self.vip = v.vip
						self.viptime = v.endtime
					end
				else
					v.status = 2
					needup = true
				end
			elseif v.kind == 2 then -- 积分清除卡
				v.score = conf[v.typeid].fmoney
			elseif v.kind == 3 then --coin card
				if v.num ~= 0 and today_first_login then
					cardmoney = cardmoney + conf[v.typeid].dmoney
					AddMoney(conf[v.typeid].dmoney, v.typeid)
					local m = {uid = self.uid, id = v.typeid, type = 1, money = conf[v.typeid].dmoney}
					Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
					v.num = v.num - 1
					needup = true
				end
				if v.num == 0 then
					v.status = 2
					needup = true
				end
			elseif v.kind == 5 then --score card
				v.endtime = v.stime + conf[v.typeid].udays * 60*60
				if v.endtime <= os.time() then
					v.status = 2
					needup = true
				end
			elseif v.kind == 6 then --free face card
				v.endtime = v.stime + conf[v.typeid].udays * 60*60
				if v.endtime <= os.time() then
					v.status = 2
					needup = true
				else
					self.free_face_time = v.endtime
				end
			end
		end
	end
	if needup then
		Send("mysql", nil, cmd.SQL_UPDATE_TOOLS, tools)
	end
	return vipmoney, cardmoney
end

local function InitSelfTools(today_first_login)
	local result = Call("mysql", nil, cmd.SQL_GET_SELF_TOOLS, self.uid)
	local vipadd = 0
	local cardadd = 0
	self.vip = 0
	self.viptime = 0
	if result and #result ~= 0 then
		tools = {}
		for k, v in pairs(result) do
			local tool = {
				typeid = tonumber(result[k][1]),
				status = tonumber(result[k][2]),
				stime = tonumber(result[k][3]),
				num = tonumber(result[k][4]),
				id = tonumber(result[k][5])
			}
			tools[tool.id] = tool
		end
		vipadd, cardadd = UpdateToolsConf(today_first_login)
	end
	return vipadd, cardadd
end

local function DayPlayTask(id) -- 每日对局任务
	local money = 0
	local dtmoney = 0
		local msg = {uid = self.uid, taskid = id, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
		local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
		if ret and not self.lockmoney then
			self.taskmoneylock = true
			if self.pfid == serverconf.pfid.talker then
				money = task.reward_money[id][4]
				dtmoney = 10 * task.reward_money[id][5]
			else
				money = task.reward_money[id][1]
				dtmoney = 10 * task.reward_money[id][2]
			end
			AddDtmoney(dtmoney, id)
			AddMoney(money, id)
			local m = {uid = self.uid, id = id, type = 1, money = money}
			local n = {uid = self.uid, id = id, type = 3, dtmoney = math.floor(dtmoney) / 10}
			Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
			Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, n)
			Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, id, money, 0)
			self.taskmoneylock = false
		end
end

local function DayHonorTask(id) -- 荣誉榜点亮任务
	local msg = {uid = self.uid, taskid = id, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
	if ret and not self.lockmoney then
		local money = 0
		self.dayhonor = self.dayhonor + 1
		self.weekhonor = self.weekhonor + 1
		if self.pfid == serverconf.pfid.talker then
			dtmoney = 10 * task.reward_money[id][3]
		else
			dtmoney = 10 * task.reward_money[id][1]
		end
		AddDtmoney(dtmoney, id)
		local n = {uid = self.uid, id = id, type = 3, dtmoney = math.floor(dtmoney) / 10}
		Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, n)
		Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, id, money, 0)
	end
end

local function SendNotice()
	local result = Call("mysql", nil, cmd.SQL_GET_NOTICE)
	if result then
		Send("player", self.uid, nil, result)
	else
		Send("log", nil, cmd.ERROR_LOG, "Get notice error")
	end
end

local GetSafeBox = function(body)
	local have = 0
	if not self.safebox then
		local result = Call("mysql", nil, cmd.SQL_GET_SAFE_BOX, self.uid)
		if result then
			if #result ~= 0 then
				self.safebox = {money = (result[1][1]), pwd = result[1][2],
					question = result[1][3], answer = result[1][4],
					uid = self.uid, upmoney = 0}
				have = 1
			end
		end
	else
		have = 1
	end
	Send("player", self.uid, cmd.SMSG_SELF_BOX, have)
end

local function GetTop20Players()
	local onetime, list = Call("redis", nil, "get_last_list")
	local pack = {}
	for k, v in ipairs(list) do
		local plr_info = MSG.pack("player_info_last", v)
		table.insert(pack, plr_info)
	end
	Send("player", self.uid, cmd.SMSG_GET_LAST_LIST, onetime, pack)
end

local GetLastHonorList = function(body)
	local _ = MSG.upack(cmd.CMSG_GET_LAST_LIST, body)
	GetTop20Players()
end

local function SendMoney(sourceuid, touid, money, logtype)
	local curmoney = 0
	local sqlpfid = 0
	local msg = {uid = touid, upmoney = money}
	skynet.send("mysql", "lua", cmd.SQL_SEND_MONEY, msg)
	local result, pfid, platfrom = skynet.call("mysql", "lua", cmd.SQL_GET_MONEY_VALUE, touid)
	pfid = tonumber(pfid)
	platfrom = tonumber(platfrom)
	if not platfrom then
		platfrom = 0
	end
	if platfrom > 0 then
		sqlpfid = pfid * 100 + platfrom
	else
		sqlpfid = pfid
	end
	if result and #result ~= 0 then
		curmoney = result[1][1]
	end
	local sql = {
		uid			= touid,
		typeid		= logtype,
		addmoney	= money,
		curmoney	= curmoney,
		pfid		= sqlpfid
		}
	if assistid then
		sql.assistid = assistid
	else
		sql.assistid = 0
	end
	skynet.send("mysql", "lua", cmd.SQL_MONEY_LOG, sql)
end

local function GetSelfDataAgain()
	if not self.lockmoney and not self.lock and not self.taskmoneylock then
		local id = task.id.friend_send
		local money = task.reward_money[id]
		self.money = self.money + money
		if self.money > minmoney_fastenter then
			self.redpackettime = 0
			self.redstarttime = 0
		end
	end
end

local function Reply1(num, tuid, fName, tName)
	if self.lock then
		return
	end
	self.lock = true
	local id = task.id.friend_send
	local money = task.reward_money[id]
	local flag = 0
	if num == 1 and not self.lockmoney then
		if self.money >= 3000 then -- 玩家所持金币大于3000才能资助别人
			LoseMoney(money, id)
			SendMoney(self.uid, tuid, money, id)
			Send("player", self.uid, cmd.SMSG_ADD_MONEY, self.uid, id, -money, 0)
			Send("center", tuid, cmd.EVENT_ADD_MONEY_ANOTHER, tuid, id, money, 0)
			flag = 1
			Send("center", tuid, cmd.EVENT_REPLY_DEMAND_MONEY, tuid, flag, fName, tName)
			local m = {uid = tuid, id = id, type = 1, money = money} -- type = 1 获得金币  type = 2 获得道具
			Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
		else
			flag = 2
		end
	else
		flag = 0
		Broadcast(true, cmd.SMSG_REPLY_DEMAND_MONEY, flag, fName, tName)
	end
	self.lock = false
end

local function LoginSucc()
	local result, task_new, name, header, pfid, platfrom = Call("mysql", nil, cmd.SQL_GET_LOGIN_CONF, self.uid)
	self.name = name
	self.header = header
	self.loginnum = 1
	self.pfid = tonumber(pfid)
	self.platfrom = tonumber(platfrom)
	if not self.platfrom then
		self.platfrom = 0
	end
	if not self.pfid then
		self.pfid = 0
	end
	if self.platfrom > 0 then
		self.sqlpfid = tonumber(100 * self.pfid + self.platfrom)
	else
		self.sqlpfid = self.pfid
	end
	local loginmoney = 0
	local vipmoney = 0
	local cardmoney = 0
	local isfirstlogin = false
	local conf = {uid = self.uid}
	if result and #result ~= 0 then
		conf.lasttime = tonumber(result[1][1])
		conf.loginnum = tonumber(result[1][2])
		conf.firstlogintime = tonumber(result[1][3])
		conf.loginreward = tonumber(result[1][4])
		if conf.lasttime == 0 then -- 新注册的用户
			isfirstlogin = true
		end
		local t = os.time({year=os.date("%Y"), month=os.date("%m"), day=os.date("%d"), hour=0})
		local maxlogincount = task.MaxDayLoginCount()
		if self.pfid == serverconf.pfid.talker then
			conf.loginnum = conf.loginnum + 8
		else
			maxlogincount = maxlogincount - 8
		end
		if conf.lasttime > t - 24*60*60 and conf.lasttime < t then --最后一次登录时间在昨天，满足连续登陆条件
			if conf.loginnum < maxlogincount then
				conf.loginnum = conf.loginnum + 1
			elseif conf.loginnum > maxlogincount then
				conf.loginnum = maxlogincount
			end
			conf.firstlogintime = os.time()
			conf.loginreward = 1
			vipmoney, cardmoney = InitSelfTools(true)
		elseif conf.lasttime < t - 24*60*60 then --最后一次登录时间在昨天之前，不满足连续登陆条件
			if conf.lasttime == 0 then
				conf.loginnum = 0
			else
				conf.loginnum = 1
			end
			conf.firstlogintime = os.time()
			InitSelfTools(true)
--			InitSelfTools(false)
		else -- 今天不是第一次登陆
			loginmoney = 1
			InitSelfTools(false)
		end
		conf.lasttime = os.time()
		Send("mysql", nil, cmd.SQL_UPDATE_LOGIN_CONF, conf)
		self.loginnum = conf.loginnum
	end
	self.login = true
	local ret = Call("mysql", nil, cmd.SQL_GET_SAFE_BOX, self.uid)
	if ret then
		if #ret ~= 0 then
			self.safebox = {money = (ret[1][1]), pwd = ret[1][2],
				question = ret[1][3], answer = ret[1][4],
				uid = self.uid, upmoney = 0}
		end
	end
	local title = Call("mysql", nil, cmd.SQL_GET_TITLE, self.score)
	local vip = GetSelfVip()
	self.firstbuy = 0
	local res = Call("mysql", nil, cmd.SQL_FIRST_BUYER, self.uid)
	if res and #res ~= 0 then
		self.firstbuy = 1	
	end
	Send("player", self.uid, cmd.SMSG_LOGIN_SUCC, 0, self.money, vip, self.loginnum, self.score, self.wincount, self.losecount, self.drawcount,
	self.monthwin, self.monthlose, self.monthdraw, title, loginmoney, vipmoney, cardmoney, task_new, isfirstlogin, self.qq_vip, math.floor(self.dtmoney) / 10, self.firstbuy)
	ChangeState(agent_state.login_succ)
	SendNotice()
	WriteLog(cmd.DAY_LOG, "login succ")
	local s = {uid = self.uid, addr = addr, typeid = 1, pfid = self.sqlpfid}
	Send("log", nil, cmd.LOGIN_LOG, s)
	logintime = os.time()
	Send("center", nil, cmd.EVENT_GET_PFID, self.uid, self.sqlpfid)
	CurTaskconf()
	GetTopList(3)
	if self.protect >= task.count[task.id.protect] and self.money < minmoney_fastenter and self.redpacket < task.count[task.id.redpacket] then
		local time = CheckRedPacketTime()
		self.redstarttime = tonumber(os.time())
		Send("player", self.uid, cmd.SMSG_RED_PACKET, time)
	end
	if conf.loginreward and conf.loginreward == 1 and not isfirstlogin then
		Send("redis", "update_login_num")
		if loginmoney == 0 then
			local msg = {pfid = self.sqlpfid, date = tonumber(os.date("%Y%m%d"))}
			Send("mysql", nil, cmd.SQL_UPDATE_ACTIVER, msg)
		end
	end
	if isfirstlogin then
		AddMoney(0, serverconf.money_log.new_player)
	end
end

local Login = function(body)
	ChangeState(agent_state.login_in)
	local uid, key, info = MSG.upack(cmd.CMSG_LOGIN, body)
	print("key = ", key, uid, info)
	if uid == 1539 then
		skynet.error("recv adam login request.")
	end
	uid = tonumber(uid)
	local result = true
	local err = 0
	if not serverconf.TEST_MODEL then
		result = BlockCall("redis", nil, "login_key", uid, key)
	end
	if not serverconf.TEST_MODEL and not result then
		err = errcode.LOGIN_KEY_ERROR
	else
		local ret, sid, address, packtype, uplose = Call("center", nil, cmd.EVENT_LOGIN, uid, sessionid, ptype)
		if ret == 0 then
			self.sumlose = 0
			ptype = packtype
			self.uid = uid
			self.info = info
			self.uplose = uplose
			connected = true
			if not self.uplose then
				self.uplose = {}
			end
			if not self.uplose[uid] then
				self.uplose[uid] = {}
			else
				for k, v in pairs(self.uplose) do
					if k == self.uid then
						for i, j in pairs(v) do
							self.sumlose = self.sumlose + j.lose
						end
					end
				end
			end
			if GetSelfGameConf() then
				LoginSucc()
			else 
				connected = false
				err = errcode.HAVE_NO_THIS_ID
			end
		elseif ret == errcode.LOGIN_AT_OTHER then
			local cl = client
			self.uid = uid
			if address then
				client = address
				sessionid = sid
			end
			if cl ~= client then
				err = errcode.LOGIN_AT_OTHER
			end
		else
			err = ret
		end
	end
	if err ~= 0 then
		print("@@@@@@@@@@@@@@@@@quit client", client)
		Send("player", self.uid, cmd.SMSG_LOGIN_FAILD, err)
		WriteLog(cmd.DAY_LOG, string.format("login failed:%d", err))
		Exit()
	end
end

local LoginOut = function(body)
	local uid =  MSG.upack(cmd.CMSG_LOGIN_OUT, body)
	Send("player", self.uid, cmd.SMSG_LOGOUT_SUCC)
	WriteLog(cmd.DAY_LOG, "login out")
	local s = {uid = self.uid, addr = addr, typeid = 2, pfid = self.sqlpfid}
	Send("log", nil, cmd.LOGIN_LOG, s)
	connected = false
	Exit()
end

local EnterRoom = function(body)
	if self.lock then
		return
	end
	self.lock = true
	ChangeState(agent_state.enter_room)
	local roomid = MSG.upack(cmd.CMSG_ENTER_ROOM, body)
	if self.roomid then
		roomid = self.roomid
	end

	if not self.uplose[self.uid] then
		self.uplose[self.uid] = {}
	end
	if not self.uplose[self.uid][roomid] then
		self.uplose[self.uid][roomid] = {}
		self.uplose[self.uid][roomid].lose = 0
	end

	if (roomid >= 24 and roomid <= 73) or (roomid >= 119 and roomid <= 128) or (roomid >= 147 and roomid <= 156) or (roomid >= 157 and roomid <= 166)then --数字表示不同类型区的roomid
		self.roomtype_li = 1
	elseif (roomid >= 1 and roomid <= 5) or (roomid >= 74 and roomid <= 118) or (roomid >= 129 and roomid <= 138) then
		self.roomtype_li = 2
	elseif (roomid >= 6 and roomid <= 13) or (roomid >= 139 and roomid <= 146) or (roomid >= 167 and roomid <= 180) then
		self.roomtype_li = 3
	end
	local ret, rconf = Call("room", nil, cmd.CMSG_ENTER_ROOM, self.uid, roomid, self.info, self.uplose, self.sumlose, self.roomtype_li)
	if ret == 0 or ret == -1 then
		self.roomid = roomid
		roomconf = rconf
	end
	if self.seatid then -- 断线重连时玩家有座位的情况
		if roomconf.roomtype == 1 or roomconf.roomtype == 2 then
			self.gametime = self.gametime + tonumber(os.time()) - self.starttime
			local time = CheckGameTime()
			Send("player", self.uid, cmd.SMSG_SCRATCH_TIME, time)
			self.starttime = tonumber(os.time())
		end
		Send("player", self.uid, cmd.SMSG_UP_GAME_DATA, self.uid, self.money, self.score, self.vip)
	end
	EnterResp(ret)
	self.lock = false
end

local function FastEnter(enterconf)
	if self.lock then
		return
	end
	self.lock = true
	ChangeState(agent_state.enter_room)
	enterconf.protectmoney = task.reward_money[task.id.protect]
	local ret, rconf, seatid, isprotect, in_nosit = Call("room", nil, cmd.CMSG_FAST_ENTER, enterconf, self.uplose, self.sumlose)
	if ret == 0 then
		self.roomid = rconf.roomid
		roomconf = rconf
		self.seatid = seatid
	end
	EnterResp(ret)
	if ret == 0 then
		ChangeState(agent_state.sit_down)
		if isprotect and not BreakProtect() then
			if self.roomid and self.seatid then
				local ret = Call("room", nil, cmd.CMSG_STAND, self.uid, self.roomid, self.seatid, false)
				self.seatid = nil
				Send("player", self.uid, cmd.SMSG_SIT_FAILD, errcode.HAVE_NO_ENOUGH_MONEY)
				if roomconf.roomtype == 1 then
					DemandWindown()
				end
				ChangeState(agent_state.at_room)
			end
		elseif enterconf.roomtype ~= 1 and in_nosit then
			if self.roomid and self.seatid then
				local ret = Call("room", nil, cmd.CMSG_STAND, self.uid, self.roomid, self.seatid, false)
				self.seatid = nil
				Send("player", self.uid, cmd.SMSG_SIT_FAILD, errcode.HAVE_NO_ENOUGH_MONEY)
				ChangeState(agent_state.at_room)
			end
		elseif self.money > roomconf.maxmoney then
			local ret = Call("room", nil, cmd.CMSG_STAND, self.uid, self.roomid, self.seatid, false)
			self.seatid = nil
			Send("player", self.uid, cmd.SMSG_SIT_FAILD, errcode.HAVE_TOO_MANY_MONEY)
			ChangeState(agent_state.at_room)
		else
			if self.seatid then
				local seaters = {}
				local seater = MSG.pack("seater", self.uid, self.seatid)
				table.insert(seaters, seater)
				Broadcast(true, cmd.SMSG_SOMEONE_SIT, seaters)
				SitResp(ret, self.seatid) 
			end
		end
	end
	self.lock = false
end

local PlayerFastEnter = function(body)
	local roomtype, gametype = MSG.upack(cmd.CMSG_FAST_ENTER, body)
	local enterconf = {
				roomtype = roomtype,
				gametype = gametype, 
				uid = self.uid,
				basebet = nil,
				money = self.money,
				roomid = nil,
				info = self.info,
				IP = GetIP()}
	FastEnter(enterconf)
end

local BankerEnter = function(body)
	if not self.roomid and not self.enterlock then
		self.enterlock = true
		local basebet, bankermoney = MSG.upack(cmd.CMSG_BAKER_ENTER, body)
		if not self.money or not bankermoney or bankermoney < self.money then
			EnterResp(errcode.HAVE_NO_ENOUGH_MONEY)
		else
			self.money = self.money - bankermoney
			local enterconf = {
				uid = self.uid,
				basebet = basebet,
				bankermoney = bankermoney,
				info = self.info,
				IP = GetIP()}
			local ret, rconf, seatid = BlockCall("room", nil, cmd.EVENT_BANKER_ENTER, enterconf)
			if ret == 0 then
				self.roomid = rconf.roomid
				roomconf = rconf
				self.seatid = seatid
			end
			EnterResp(ret)
		end
		self.enterlock = false
	end
end

local Sit = function(body)
	if self.lock then
		return
	end
	self.lock = true
	ChangeState(agent_state.sit_down)
	local ret = 0
	local seatid = MSG.upack(cmd.CMSG_SIT, body)
	if self.money < roomconf.minmoney and roomconf.roomtype == 1 and self.protect < task.count[task.id.protect] then
		BreakProtect()
	end
	if not self.uplose[self.uid] then
		self.uplose[self.uid] = {}
	end
	if not self.uplose[self.uid][self.roomid] then
		self.uplose[self.uid][self.roomid] = {}
		self.uplose[self.uid][self.roomid].lose = 0
	end
	if self.money < roomconf.minmoney then
		ret = errcode.HAVE_NO_ENOUGH_MONEY;
	--elseif self.money > roomconf.maxmoney then
		--ret = errcode.HAVE_TOO_MANY_MONEY
	else
		if self.uplose[self.uid][self.roomid].lose < serverconf.uplosemoney[0] then
			ret = errcode.OVER_SUMLOSE_LIMIT
		elseif self.uplose[self.uid][self.roomid].lose < serverconf.uplosemoney[roomconf.roomtype] then
			ret = errcode.OVER_LOSE_LIMIT
		else
			ret, seatid = Call("room", nil, cmd.CMSG_SIT, self.uid, self.roomid, seatid, self.money, GetIP())
		end
	end
	SitResp(ret, seatid)
	self.lock = false
end

local TryStand = function(body)
	if self.lock then
		return
	end
	self.lock = true
	if self.roomid and self.seatid then
		local ret =	PlayerTryStand()
		self.lock = false
		if ret == 0 then
			return true
		else
			return false
		end
	end
end

local Stand = function(body)
	if self.roomid and self.seatid then
		TryStand()
	end
end

local QuitRoom = function(body)
	if self.roomid then
		TryQuit()
	end
end

local ChangePoker = function(body)
	if self.seatid then
		Send("game", nil, cmd.CMSG_CHANGE_POKER, body)
	end
end

local ChoicePokerType = function(body)
	if self.seatid then
		Send("game", nil, cmd.CMSG_CHOICE_POKER, body)
	end
end

local ChoiceSPType = function(body)
	if self.seatid then
		Send("game", nil, cmd.CMSG_CHOICE_SP_TYPE, body)
	end
end

local BFChoicePokerType = function(body)
	if self.seatid then
		Send("game", nil, cmd.CMSG_BF_POKER_TYPE, body)
	end
end

local GetRoomList = function(body)
	local type = MSG.upack(cmd.CMSG_TABLE_GETALL, body)
	local retroom = Call("room", nil, cmd.CMSG_TABLE_GETALL, type)
	if not retroom then
		retroom = {}
	end
	Send("player", self.uid, nil, retroom)
end

local GetOnline = function(body)
    local result = Call("mysql", nil, cmd.SQL_GET_ALL_GIRLS)
	if result then
		if #result ~= 0 then
			Send("center", nil, cmd.CMSG_GET_ONLINE, self.uid, result)	
		else
			Send("center", nil, cmd.CMSG_GET_ONLINE, self.uid, {})	
		end
	end
end

local GetOnlineInfo = function(body)
	if self.uid then
		Send("center", nil, cmd.CMSG_GET_ONLINEINFO, self.uid, body)
	end
end

local UpdateFriend = function(body)
	if self.uid then
		Send("center", nil, cmd.CMSG_UPDATE_FRIEND, self.uid, body)
	end
end

local ChatAtRoom = function(body)
	local msg = MSG.upack(cmd.CMSG_ROOM_CHAT, body)
	Broadcast(true, cmd.SMSG_ROOM_CHAT, self.uid, msg)
end

local ChatTo = function(body)
	local id, msg = MSG.upack(cmd.CMSG_CHAT_TO, body)
	Send("center", nil, cmd.CMSG_CHAT_TO, id, self.uid, msg)
end

local function ReplyDemandMoney(body)
	local num, tuid, fName, tName = MSG.upack(cmd.CMSG_REPLY_DEMAND_MONEY, body)
	Reply1(num, tuid, fName, tName)
end

local function ChoiceDemandFriend(body)
	local demandfids = MSG.upack(cmd.CMSG_CHOICE_FRIEND_DEMAND, body)
	if self.uid then
		Send("center", nil, cmd.CMSG_CHOICE_FRIEND_DEMAND, self.uid, demandfids)
	end
end

local ChangeRoom = function(body)
	if self.lock then
		return
	end
	if self.roomid then
		local enterconf = {
			roomtype = roomconf.roomtype,
			gametype = roomconf.gametype, 
			uid = self.uid,
			basebet = roomconf.basebet,
			money = self.money,
			roomid = self.roomid,
			info = self.info,
			IP = GetIP()}

		if self.money < roomconf.minmoney then
			if roomconf.roomtype ~= 1 then
				if TryQuit() then
					FastEnter(enterconf)
				else
--					skynet.error(string.format("ChangeRoom failed uid = %d, money = %d, roomid = %d", self.uid, self.money, self.roomid))
				end
			else
				ChangeState(agent_state.at_room)
				Send("player", self.uid, cmd.SMSG_QUIT_FAILD, errcode.HAVE_NO_ENOUGH_MONEY)
				WriteLog(cmd.DEBUG_LOG, string.format("Changeroom quit failed, errorid:%d", errcode.HAVE_NO_ENOUGH_MONEY))
				DemandWindown()
			end
		else
			if TryQuit() then
				FastEnter(enterconf)
			else
--				skynet.error(string.format("ChangeRoom failed uid = %d, money = %d, roomid = %d", self.uid, self.money, self.roomid))
			end
		end
	end
	self.lock = false
end

local SendFace = function(body)
	if self.seatid and not self.lockmoney then
		local faceid = MSG.upack(cmd.CMSG_FACE, body)
		local cost = GetFaceCost(faceid)
		if cost == 0 or not self.lockmoney and cost < self.money - roomconf.minmoney then
			if cost ~= 0 then
				LoseMoney(cost, serverconf.money_log.face)
				local backconf = {money = cost, gametype = roomconf.gametype,
					roomtype = roomconf.roomtype, moneytype = roomconf.basebet, pfid = self.sqlpfid}
				Send("mysql", nil, cmd.SQL_BACK_MONEY, backconf)
			end
			Broadcast(true, cmd.SMSG_FACE, self.uid, faceid, cost)
		end
	end
end

local AddFriend = function(body)
    local fid = MSG.upack(cmd.CMSG_ADD_FRIEND, body)
    local msg = {uid = self.uid, fid = fid}
    Send("mysql", nil, cmd.SQL_ADD_FRIEND, msg)
    Send("player", self.uid, cmd.SMSG_ADD_FRIEND, fid)
	Send("player", fid, cmd.SMSG_ADD_FRIEND, self.uid)
	Send("center", nil, cmd.EVENT_ADD_FRIEND, self.uid, fid)
end

local DelFriend = function(body)
    local fid = MSG.upack(cmd.CMSG_DEL_FRIEND, body)
    local msg = {uid = self.uid, fid = fid}
    Send("mysql", nil, cmd.SQL_DEL_FRIEND, msg)
    Send("player", self.uid, cmd.SMSG_DEL_FRIEND, fid)
	Send("center", nil, cmd.EVENT_DEL_FRIEND, self.uid, fid)
end

local CreatSafeBox = function(body)
	local succ = false
	if not self.safebox then
		local pwd, question, answer = MSG.upack(cmd.CMSG_CREAT_SAFE_BOX, body)
		self.safebox = {money = 0, upmoney = 0, pwd = myclib.md5(pwd),
			question = question,answer = answer, uid = self.uid}
			succ = true
			self.safebox.login = true
			UpdateSafeBoxToDB()
	end
    Send("player", self.uid, cmd.SMSG_CREAT_SAFE_BOX, succ)
end

local LoginSafeBox = function(body)
    local pwd = MSG.upack(cmd.CMSG_LOGIN_SAFE_BOX, body)
	if not self.safebox then
	    local result = Call("mysql", nil, cmd.SQL_GET_SAFE_BOX, self.uid)
	    if result then
			if #result ~= 0 then
				self.safebox = {money = (result[1][1]), pwd = result[1][2],
					question = result[1][3], answer = result[1][4],
					uid = self.uid, upmoney = 0}
			end
	    end 
	end
	local packet
	if self.safebox then
		pwd = myclib.md5(pwd)
		if pwd == self.safebox.pwd then
			Send("player", self.uid, cmd.SMSG_LOGIN_SAFE_BOX, true, self.safebox.money, 0)
			self.safebox.login = true
		else
			Send("player", self.uid, cmd.SMSG_LOGIN_SAFE_BOX, false, 0, errcode.SAFE_BOX_PWD_WRONG)
		end
	else
		Send("player", self.uid, cmd.SMSG_LOGIN_SAFE_BOX, false, 0, errcode.SAFE_BOX_NO_OPEN)
	end
end

local DealSafeBoxCoin = function(body)
	local vip = GetSelfVip()
	local topmoney = 0
	if types.SAFE_BOX_MAX_MONEY[vip] then
		topmoney = types.SAFE_BOX_MAX_MONEY[vip]
	end
	if self.safebox and self.safebox.login then
		local t, money = MSG.upack(cmd.CMSG_COIN_SAFE_BOX,body)
		local succ = false
		if t == 0 and money <= tonumber(self.safebox.money) then
			AddMoney(money, serverconf.money_log.safe_box)
			self.safebox.money = self.safebox.money - money
			self.safebox.upmoney = self.safebox.upmoney - money
			succ = true
		else
			if t == 1 and not self.seatid and self.money >= money and (tonumber(self.safebox.money) + money) < types.SAFE_BOX_MAX_MONEY[vip] then
				LoseMoney(money, serverconf.money_log.safe_box)
				self.safebox.money = self.safebox.money + money 
				self.safebox.upmoney = self.safebox.upmoney + money
				money = -money
				succ = true
			end
			if t == 1 and not self.seatid and self.money >= money and (tonumber(self.safebox.money) + money) >= types.SAFE_BOX_MAX_MONEY[vip] then
				money = types.SAFE_BOX_MAX_MONEY[vip] - (tonumber(self.safebox.money))
				LoseMoney(money, serverconf.money_log.safe_box)
				self.safebox.money = self.safebox.money + money 
				self.safebox.upmoney = self.safebox.upmoney + money
				money = -money	
				succ = true
			end
		end
		if succ then
			if self.roomid then
				Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, 1, money)
			else
				Send("player", self.uid, cmd.SMSG_ADD_MONEY, self.uid, 1, money, tonumber(-1))
			end
			UpdateSafeBoxToDB()
		end
		Send("player", self.uid, cmd.SMSG_COIN_SAFE_BOX, succ)
	end
end

local GetSafeBoxPwd = function(body)
    local question, answer = MSG.upack(cmd.CMSG_GET_PWD,body)           
	if not self.safebox then
	    local result = Call("mysql", nil, cmd.SQL_GET_SAFE_BOX, self.uid)
	    if result then if #result ~= 0 then
				self.safebox = {money = tonumber(result[1][1]), pwd = result[1][2],
					question = result[1][3], answer = result[1][4],
					uid = self.uid, upmoney = 0}
			end
	    end 
	end
	if self.safebox  and question == self.safebox.question and answer == self.safebox.answer then
		local pwd = tostring(os.time())
		self.safebox.pwd = myclib.md5(pwd)
		Send("player", self.uid, cmd.SMSG_SAFE_BOX_PWD, true, pwd)                                           
		UpdateSafeBoxToDB()
	else
		Send("player", self.uid, cmd.SMSG_SAFE_BOX_PWD, false, tostring(0))                                           
	end
end

local ChangeSafeBoxPWD = function(body)
	local succ = false
	if self.safebox and self.safebox.login then
		local newpwd, oldpwd = MSG.upack(cmd.CMSG_SAFE_BOX_CHANGE_PWD, body)
		if self.safebox.pwd == myclib.md5(oldpwd) then
			self.safebox.pwd = myclib.md5(newpwd)
			succ = true
			UpdateSafeBoxToDB()
		end
	end
	Send("player", self.uid, cmd.SMSG_SAFE_BOX_CHANGE_PWD, succ)
end

local ChangeSafeBoxQuestion = function(body)
	local succ = false
	if self.safebox.login then
		local question, answer, newq, newa = MSG.upack(cmd.CMSG_SB_CHANGE_QUESTION, body)
		if question == self.safebox.question and answer == self.safebox.answer then
			self.safebox.question = newq
			self.safebox.answer = newa
			succ = true
		end
	end
	Send("player", self.uid, cmd.SMSG_SB_CHANGE_QUESTION, succ)
end


local Tocards = function() --将数据库的besttype值转换成5个card的格式
	local value = {1e10, 1e8, 1e6, 1e4, 1e2}
	local choicecards = {}
	local cards = {}
	local pokertype = 0
	self.besttype = tonumber(self.besttype)
	local tmp = math.floor(self.besttype / 1e10)
	if tmp == 0 then
		self.besttype = 0
	end
	for j = 1, 5 do
		local card = {}
		card.suit = math.floor(self.besttype / value[j]) % 4
		if card.suit == 0 then
			card.suit = 4
		end
		card.point = math.floor((math.floor(self.besttype / value[j] % 100) - card.suit) / 4) + 2
		table.insert(cards, card)
	end
	pokertype = casino.GetBFType(cards, choicecards) --将牌理好的功能
	if self.besttype == 0 then --初始化状态数据库besttype值默认为0，这时将pokertype设为-1
		pokertype = -1
	end

	return choicecards, pokertype
end

local function GetRedPacketReward()
	local id = task.id.redpacket
	local money = task.reward_money[id][1]
	local msg = {uid = self.uid, taskid = id, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
	if ret then
		AddMoney(money, id)
		local m = {uid = self.uid, id = id, type = 1, money = money}
		Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
	end
	if self.roomid then
		Broadcast(true, cmd.SMSG_GET_REDPACKET_REWARD, self.uid, id, money)
	else
		Send("player", self.uid, cmd.SMSG_GET_REDPACKET_REWARD, self.uid, id, money)
	end
	self.redpacket = self.redpacket + 1
	self.redstarttime = 0
	self.redpackettime = 0
end

local function GetScratchReward() -- 刮刮乐任务
	local id = task.id.scratch
	local msg = {uid = self.uid, taskid = id, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
	if ret and not self.lockmoney then
		local money = 0
		local dtmoney = 0
		if self.pfid == serverconf.pfid.talker then
			if sign == 1 then
				money = math.random(200, 400)
			elseif sign == 2 then
				money = math.random(100, 200)
			elseif sign == 3 then
				money = math.random(400, 600)
			elseif sign == 4 then
				dtmoney = 10
			elseif sign == 5 then
				money = math.random(600, 900)
			elseif sign == 6 then
				dtmoney = 10
			end
		else
			if sign == 1 then
				money = math.random(400, 500)
			elseif sign == 2 then
				money = math.random(200, 300)
			elseif sign == 3 then
				money = math.random(600, 800)
			elseif sign == 4 then
				dtmoney = 10
			elseif sign == 5 then
				money = math.random(1000, 1200)
			elseif sign == 6 then
				dtmoney = 20
			end
		end
		if sign == 4 or sign == 6 then
			AddDtmoney(dtmoney, id)
			local n = {uid = self.uid, id = id, type = 3, dtmoney = math.floor(dtmoney) / 10}
			Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, n)
		else
			AddMoney(money, id)
			local m = {uid = self.uid, id = id, type = 1, money = money}
			Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
		end
			Broadcast(true, cmd.SMSG_SCRATCH_SEND_REWARD, self.uid, sign, money, math.floor(dtmoney) / 10)
			self.scratch = self.scratch + 1
			self.scratchflag = false
	end
end

local function GetSelfGameinfo()
	local title = Call("mysql", nil, cmd.SQL_GET_TITLE, self.score)
	local vip = GetSelfVip()
	local packet = MSG.pack(cmd.SMSG_PLAYER_GAMEINFO, self.uid, self.money, vip, self.score, self.wincount, self.losecount, self.drawcount,
	self.monthwin, self.monthlose, self.monthdraw, title, 0, tostring(self.besttype))
	return packet
end

local GetPlayerGameInfo = function(body)
	local playerid = MSG.upack(cmd.CMSG_GET_PLAYER_GAMEINFO, body)
	local packet = nil
	if playerid == self.uid then
		packet = GetSelfGameinfo()
	else
		packet = Call("center", nil, cmd.EVENT_GET_PLAYER_GAMEINFO, playerid)
	end
	if packet then
		Send("player", self.uid, nil, packet)
	end
end

local SelfToolConf = function(body)
	local t = {}
	local now = os.time()
	for k, v in pairs(tools) do
		if v.status ~= 2 then
			if v.endtime and v.endtime > now then
				local tool = MSG.pack("tool", v.id, v.typeid, (v.endtime - now), tonumber(-1))
				table.insert(t, tool)
			elseif v.num and v.num > 0 then
				local tool = MSG.pack("tool", v.id, v.typeid, tonumber(-1), v.num)
				table.insert(t, tool)
			end
		end
	end
	Send("player", self.uid, cmd.SMSG_SELF_TOOLS_CONF, t)
end

local TaskNewPlayer = function(body)
	local result = Call("mysql", nil, cmd.SQL_TASK_NEW_PLAYER, self.uid)
	if result then
		local id = task.id.learn_course
		local money = task.GetReward(id)
		AddMoney(money, id)
		local m = {uid = self.uid, id = id, type = 1, money = money} -- type = 1 获得金币  type = 2 获得道具
		Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
		Send("player", self.uid, cmd.SMSG_TASK_NEW_PLAYER, true, money)
	else
		Send("player", self.uid, cmd.SMSG_TASK_NEW_PLAYER, false, 0)
	end
end

local SystemError = function(body)
	local msg = {uid = self.uid}
	msg.errors , msg.env = SMG.upack(cmd.CMSG_SYSTEM_ERROR, body)
	Send("mysql", nil, cmd.SQL_SYSTEM_ERROR, msg)
end

local GetGoodsDescribe = function(body)
	local ret = Call("shop", nil, cmd.CMSG_GOODS_DESCRIBE)
	Send("player", self.uid, nil, ret)
end

local PlayerBroadcast = function(body)
	local typeid, msg = MSG.upack(cmd.CMSG_BROADCAST, body)
	local tool = tools[typeid]
	local packet
	if tool and tool.kind == 4 and tool.status == 0 then
		tool.status = 2
		Send("center", nil, cmd.CMSG_BROADCAST, msg)
		Send("mysql", nil, cmd.SQL_USE_TOOL, tool)
		Send("player", self.uid, cmd.SMSG_USE_TOOL, self.uid, true, typeid, 0, 0, nil)
	else
		Send("player", self.uid, cmd.SMSG_USE_TOOL, self.uid, false, typeid, 0, 0, nil)
	end
end

local UseTool = function(body)
	local typeid = MSG.upack(cmd.CMSG_USE_TOOL, body)
	local tool = tools[typeid]
	local tool_conf = {uid = self.uid, typeid = typeid}
	if tool and tool.status == 0 then
		local packet
		local needbroadcast = false
		local succ = false
		local conf = Call("shop", nil, cmd.EVENT_TOOLS_CONF)	
		if conf[tool.typeid].typeid == 6 then
			tool.status = 2
			tool.endtime = os.time() + conf[tool.typeid].udays * 24*60*60
			tool_conf.status = 1
			self.free_face_time = tool.endtime
			succ = true
			packet = MSG.pack(cmd.SMSG_USE_TOOL, self.uid, true, typeid, 0, 0, nil)
		elseif conf[tool.typeid].typeid == 2 then
			local s = 0
			if tool.score == 0 then
				s = - self.score
			else
				if self.score < 0 then
					if -self.score > tool.score then
						s = tool.score
					else
						s = -self.score
					end
				end
			end
			self.upscore = self.upscore + s
			self.score = self.score + s
			tool.status = 2
			tool_conf.status = 2
			needbroadcast = true
			succ = true
			packet = MSG.pack(cmd.SMSG_USE_TOOL, self.uid, true, typeid, 0, s, 0)
		end
		if succ then
			if self.roomid and needbroadcast then
				Broadcast(true, nil, packet) 
			else
				Send("player", self.uid, nil, packet)
			end		
			Send("mysql", nil, cmd.SQL_USE_TOOL, tool_conf)
		end
	else
		Send("player", self.uid, cmd.SMSG_USE_TOOL, self.uid, false, typeid, 0, 0, nil)
	end
end

local GetTaskReward = function(body)
	local taskid = MSG.upack(cmd.CMSG_GET_TASK_REWARD, body)
	local succ = false
	local dayplay = self.daywin + self.daydraw + self.daylose
	if taskid == task.id.qq_vip and self.qq_vip ~= 0 or
		taskid == task.id.qq_vip_course and self.qq_vip ~= 0 or
		taskid == task.id.qq_year_vip and self.qq_vip > 10 or
		taskid == task.id.learn_course or
		taskid == task.id.day_login then
		succ = true
	end
	local money = 0
	local toall = false
	if succ then
		local msg = {uid = self.uid, taskid = taskid, date = os.date("%Y%m%d"), pfid = self.sqlpfid}
		local ret, sign = Call("mysql", nil, cmd.SQL_COMPLETE_TASK, msg)
		if taskid == task.id.qq_vip or taskid == task.id.qq_year_vip then
			sign = self.qq_vip % 10
		elseif taskid == task.id.microblog then
			sign = self.qq_vip / 100
		elseif taskid == task.id.day_login then
			sign = self.loginnum
		end
		if ret then
			money = task.GetReward(taskid, sign)
			local packet
			if money ~= 0 then
				AddMoney(money, taskid)
				toall = true
				local m = {uid = self.uid, id = taskid, type = 1, money = money}
				Send("mysql", nil, cmd.SQL_WRITE_SYSTEM_EMAIL, m)
			end
		else
			succ = false
		end
	end
	if self.roomid and toall then
		Broadcast(true, cmd.SMSG_SEND_TASK_REWARD, self.uid, succ, taskid, money)
	else
		Send("player", self.uid, cmd.SMSG_SEND_TASK_REWARD, self.uid, succ, taskid, money)
	end
end

local function RedPacket(body)
	local _ = MSG.upack(cmd.CMSG_GET_REDPACKET_REWARD, body)
	self.lockmoney = true
	local taskid = task.id.redpacket
	local num = task.count[taskid]
	self.redpackettime = self.redpackettime + tonumber(os.time()) - self.redstarttime
	CheckRedPacketTime()
	if self.redpacket < num and self.money < minmoney_fastenter and self.protect >= task.count[task.id.protect] then
		GetRedPacketReward()
		if self.money < minmoney_fastenter then
			local time = CheckRedPacketTime()
			self.redstarttime = tonumber(os.time())
			Send("player", self.uid, cmd.SMSG_RED_PACKET, time)
		end
	end
	self.lockmoney = false
end

local function Scratch(body)
	local _ = MSG.upack(cmd.CMSG_GET_SCRATCH_REWARD, body)
	local id = task.id.scratch
	local maxcount = #task.reward_money[id]
	if self.starttime == 0 then
		for i = 0, (maxcount - 1) do
			if self.scratch == i and self.gametime < task.reward_money[id][i + 1] then
				return
			end
		end
	end
	self.gametime = self.gametime + tonumber(os.time()) - self.starttime
	CheckGameTime()
	for i = 0,(maxcount - 1) do
		if self.scratch == i and self.gametime == task.reward_money[id][i + 1] and self.scratch < maxcount then
			GetScratchReward()
			break	
		end
	end
	if self.scratch < maxcount and not self.scratchflag then
		self.starttime = tonumber(os.time())
		self.gametime = 0
		Send("player", self.uid, cmd.SMSG_SCRATCH_TIME, task.reward_money[task.id.scratch][self.scratch + 1])
	end
	if self.scratch == maxcount then
		Send("player", self.uid, cmd.SMSG_SCRATCH_TIME, -1)
	end
end

local function peer_close()
	connected = false
	WriteLog(cmd.ERROR_LOG, "peer close")
	if self.sqlpfid then
		local s = {uid = self.uid, addr = addr, typeid = 3, stime = logintime, pfid = self.sqlpfid}
		Send("log", nil, cmd.LOGIN_LOG, s)
	end
	Exit()
end

local function HeartBetCB()
	local uid = 0
	if self.uid then 
		uid = self.uid
	end
	local str = string.format("player %d, heart bet timeout", uid)
	Send("log", nil, cmd.DAY_LOG, str)
	peer_close()
end

local Bet = function(body)
	local money = MSG.upack(cmd.CMSG_BET, body)
	if money < roomconf.basebet or money > math.floor(self.money/1.3) then
		Send("player", self.uid, cmd.SMSG_SOME_ONE_BET, self.uid, 0, errcode.BET_MONEY_ERROR)
	else
		Send("game", nil, cmd.EVENT_SOMEONE_BET, money)
	end
end

local GetGameInfo = function(body)
	skynet.ret(skynet.pack(GetSelfGameinfo()))
end

local Tonum = function(cards, ptype)
	local num = ""
	for k, v in pairs(cards) do
		if ((v.point - 2) * 4 + v.suit) < 10 then
			num = num .. 0 .. ((v.point - 2) * 4 + v.suit)
		else
			num = num  .. ((v.point - 2) * 4 + v.suit)
		end
	end
	if ptype < 10 then
		num = num .. 0 ..ptype
	else
		num = num .. ptype
	end
	num = tonumber(num)
	return num
end

local PlayOneMatch = function(body)
	local _, score, choicecards, pokertype = unpack(body)
	self.pokertype = pokertype
	local sqlcards, sqlpokertype = Tocards()
	if not casino.BFCompare(choicecards, pokertype, sqlcards, sqlpokertype) then --将理好的牌进行比较(数据库存储的牌和手上现在拿着的牌比较)

	else
		self.besttype = Tonum(choicecards, pokertype)
	end
	self.ptypenum = GetPtypeNum(self.pokertype)
	if math.floor(self.date / 100) ~= tonumber(os.date("%Y%m")) then
		self.daywin = 0
		self.daylose = 0
		self.daydraw = 0
		self.monthwin = 0
		self.monthlose = 0
		self.monthdraw = 0
		self.date = tonumber(os.date("%Y%m%d"))
	elseif self.date ~= tonumber(os.date("%Y%m%d")) then
		self.daywin = 0
		self.daylose = 0
		self.daydraw = 0
		self.daywinnum = 0
		self.daylosenum = 0
		self.daydrawnum = 0
		self.date = tonumber(os.date("%Y%m%d"))
	end
	local cardadd = 0
	local espacialadd = 0
	if score > 0 then
		if HaveDoubleScoreCard() then
			cardadd = score
		end
		local day = tonumber(os.date("%m%d"))
		if day > 120 and day < 129 then
			local hour = tonumber(os.date("%H"))
			if (hour > 10 and hour < 15) or (hour > 18 and hour < 22) then
				espacialadd = score
			end
		end
		self.daywinnum = self.daywinnum + 1
		self.wincount = self.wincount + 1
		self.upwincount = self.upwincount + 1
		self.monthwin = self.monthwin + 1
		self.daywin = self.daywin + 1
	elseif score < 0 then
		self.daylosenum = self.daylosenum + 1
		self.losecount = self.losecount + 1
		self.uplosecount = self.uplosecount + 1
		self.monthlose = self.monthlose + 1
		self.daylose = self.daylose + 1
	else
		self.daydrawnum = self.daydrawnum + 1
		self.drawcount = self.drawcount + 1
		self.updrawcount = self.updrawcount + 1
		self.monthdraw = self.monthdraw + 1
		self.daydraw = self.daydraw + 1
	end
	if self.dayscore == nil then
		self.dayscore = 0
	end
	self.score = self.score + score + cardadd + espacialadd
	self.upscore = self.upscore + score + cardadd + espacialadd
	self.dayscore = self.dayscore + self.upscore
	UpdatePlayNum()
	local dayplaynum = self.daywinnum + self.daylosenum + self.daydrawnum
	for i = 0, 11 do
		local id = task.id.play1_20 + i
		local m = 3
		if self.pfid == serverconf.pfid.talker then
			m = 6
		end
		if dayplaynum == task.reward_money[id][m]  then
			if (roomconf.roomtype == 1 and i >= 0 and i < 3) or
			   (roomconf.roomtype == 2 and i >= 3 and i < 6) or
			   (roomconf.roomtype == 3 and i >= 6 and i < 9) or
			   (roomconf.roomtype == 4 and i >= 9 and i < 12) then
					DayPlayTask(id)
					break
			end
		end
	end

	self.ptypenum = self.ptypenum + 1
	local msg = {uid = self.uid, ptypenum = self.ptypenum, ptype = self.pokertype, date = tonumber(os.date("%Y%m%d")), pfid = self.sqlpfid}
	Send("mysql", nil, cmd.SQL_UPDATE_PTYPENUM, msg)

	for i = 0, 14 do
		local taskid = task.id.ptype_0 + i
		local m = 2
		if self.pfid == serverconf.pfid.talker then
			m = 4
		end
		if self.ptypenum == task.reward_money[taskid][m] and self.pokertype == i then
			DayHonorTask(taskid)
			break	
		end
	end
	UpdateInfo()
	UpdateToDB()

	if score <= 0 then
		Send("player", self.uid, cmd.SMSG_PLAY_ONE_MATCH, 1)
	else
		Send("player", self.uid, cmd.SMSG_PLAY_ONE_MATCH, 2)
	end
end

local EventAddMoney = function(body) 
	local _, money, cardsid = unpack(body)
	AddMoney(money, serverconf.money_log.table_win, cardsid)
end

local LoserGetResult = function(body)
	self.lockmoney = true
	local losemoney, cardsid = Call("game", nil, cmd.EVENT_LOSER_GET_RESULT, self.money)
	LoseMoney(losemoney, serverconf.money_log.table_win, cardsid)
	local winlog = {uid = self.uid, roomid = self.roomid, escape = 0, 
		leftmoney = self.money, winmoney = -losemoney}
	Send("mysql", nil, cmd.SQL_WIN_LOG, winlog)
	self.lockmoney = false
end

local SomeOneEnter = function(body)
	local addr, uid, roomid, info, sign = unpack(body)
	if uid == self.uid then
		Send("player", self.uid, cmd.SMSG_ENTER_ROOM_SUCC, roomid)
	elseif self.roomid and roomid == self.roomid then
		if self.seatid ~= nil then
			Send("player", uid, cmd.SMSG_UP_GAME_DATA, self.uid, self.money, self.score, self.vip)
		end
		if sign == 0 then
			Send("player", self.uid, cmd.SMSG_SOMEONE_ENTER, uid, info)
		end
	end
end

local Kick = function(body)
	if self.lock then
		return
	end
	self.lock = true
	local addr, kickid = unpack(body)
	if self.seatid then
		self.lock = true
		local ret = Call("game", nil, cmd.CMSG_TRY_STAND)
		self.lock = false
		if ret == 0 then
			BeKicked()
		else
			kickid = kickid
		end
	else
		BeKicked()
	end
end

local SomeOneSit = function(body)
	local _, uid, seatid = unpack(body)
	local seaters = {}
	local packet = MSG.pack("seater", uid, seatid)
	table.insert(seaters, packet)
	Send("player", self.uid, cmd.SMSG_SOMEONE_SIT, seaters)
end

local SomeOneStand = function(body)
	local _, uid, roomid, seatid = unpack(body)
	if uid == self.uid or (uid ~= self.uid and self.roomid and self.roomid == roomid) then
		if uid == self.uid then
			WriteLog(cmd.DAY_LOG, string.format("stand from seat %d", self.seatid))
			self.seatid = nil
		end
		Send("player", self.uid,  cmd.SMSG_SOMEONE_STAND, uid, seatid)
	end
end

local SomeOneQuit = function(body)
	local _, uid, roomid = unpack(body)
	if uid == self.uid or (uid ~= self.uid and self.roomid and self.roomid == roomid) then
		if uid == self.uid then
			self.roomid = nil
			self.seatid = nil
		end
		Send("player", self.uid, cmd.SMSG_SOMEONE_QUIT, uid)
	end
end

local KickForGameOver = function(body)
	if self.lock then
--		skynet.error(string.format("1uid:%d, money:%d, roomid:%d, roomconf.minmoney:%d, custate:%d", self.uid, self.money, self.roomid, roomconf.minmoney, cur_state))
		return
	end
	if not self.uplose[self.uid] then
		self.uplose[self.uid] = {}
	end
	if not self.uplose[self.uid][self.roomid] then
		self.uplose[self.uid][self.roomid] = {}
		self.uplose[self.uid][self.roomid].lose = 0
	end
	local _, bekicked = unpack(body)
	if not connected then
--		skynet.error(string.format("2uid:%d, money:%d, roomid:%d, roomconf.minmoney:%d, custate:%d", self.uid, self.money, self.roomid, roomconf.minmoney, cur_state))
		Exit()
	elseif self.seatid and (self.uplose[self.uid][self.roomid].lose <= serverconf.uplosemoney[roomconf.roomtype] or self.sumlose <= serverconf.uplosemoney[0]) then --输的金币超出房间设置的输钱上线或超出每日总输钱上线被踢
--		skynet.error(string.format("3uid:%d, money:%d, roomid:%d, roomconf.minmoney:%d, custate:%d", self.uid, self.money, self.roomid, roomconf.minmoney, cur_state))
		Send("player", self.uid, cmd.SMSG_OVER_LOSE_LIMIT, errcode.OVER_LOSE_LIMIT)
		self.lock = true
		local ret = Call("game", nil, cmd.CMSG_TRY_STAND)
		if ret == 0 then
	--	skynet.error(string.format("4uid:%d, money:%d, roomid:%d, roomconf.minmoney:%d, custate:%d", self.uid, self.money, self.roomid, roomconf.minmoney, cur_state))
			StandSucc()
		else
	--	skynet.error(string.format("5uid:%d, money:%d, roomid:%d, roomconf.minmoney:%d, custate:%d", self.uid, self.money, self.roomid, roomconf.minmoney, cur_state))
			StandFailed(ret)
		end
		self.lock = false
	elseif self.seatid and bekicked then --2把超时操作被踢
		Send("player", self.uid, cmd.SMSG_TIMEOUT_KICK)
		self.lock = true
		local ret = Call("game", nil, cmd.CMSG_TRY_STAND)
		if ret == 0 then
--			skynet.error(string.format("Timeout be kicked succ, uid:%d, money:%d, roomid:%d",self.uid, self.money, self.roomid))
			StandSucc()
		else
--			skynet.error(string.format("Timeout be kicked failed, errorcode = %d, uid = %d, money = %d, roomid:%d", ret, self.uid, self.money, self.roomid))
			StandFailed(ret)
		end
		self.lock = false
	elseif self.seatid and self.money < roomconf.minmoney then
		if roomconf.roomtype == 1 and self.protect < task.count[task.id.protect] then
			BreakProtect()
		end
		if self.seatid and self.money < roomconf.minmoney then --所持金币不足或低于房间下线且无破产保护次数被踢
			Send("player", self.uid, cmd.SMSG_NO_MONEY_KICK, errcode.HAVE_NO_ENOUGH_MONEY)
			if roomconf.roomtype == 1 then
				DemandWindown()
				RedPacketTask()
			end
			if self.seatid then
				self.lock = true
				local ret = Call("game", nil, cmd.CMSG_TRY_STAND)
				if ret == 0 then
--					skynet.error(string.format("Have no enough money be kicked succ, uid = %d, money = %d, roomid:%d", self.uid, self.money, self.roomid))
					StandSucc()
				else
--					skynet.error(string.format("Have no enough money be kicked failed, errorcode = %d, uid = %d, money = %d, roomid:%d", ret, self.uid, self.money, self.roomid))
					StandFailed(ret)
				end
				self.lock = false
			end
		end
	elseif self.seatid and self.money > roomconf.maxmoney then --金币高于房间上线被踢
		Send("player", self.uid, cmd.SMSG_NO_MONEY_KICK, errcode.HAVE_TOO_MANY_MONEY)
		if self.seatid then
			self.lock = true
			local ret = Call("game", nil, cmd.CMSG_TRY_STAND)
			if ret == 0 then
--				skynet.error(string.format("Have too much money be kicked succ, uid = %d, money = %d, roomid:%d", self.uid, self.money, self.roomid))
				StandSucc()
			else
--				skynet.error(string.format("Have too much money be kicked failed, errorcode = %d, uid = %d, money = %d, roomid:%d", ret, self.uid, self.money, self.roomid))
				StandFailed(ret)
			end
			self.lock = false
		end
	end
	BeKicked()
end

local NoticeTime = function(body)
	self.daywin = 0
	self.daylose = 0
	self.daydraw = 0
	self.protect = 0
	self.dayhonor = 0
	self.daywinnum = 0
	self.daylosenum = 0
	self.daydrawnum = 0
	self.demand = 0
	self.uplose = {}
	self.sumlose = 0
	self.scratch = 0
	if os.date("*t", os.time()).wday == 1 then
		self.weekhonor = 0
	end
	Send("player", self.uid, cmd.SMSG_A_NEW_DAY)
end

local TakeFee = function(body)
	local _, money, msg = unpack(body)
	msg.pfid = self.sqlpfid
	Send("mysql", nil, cmd.SQL_BACK_MONEY, msg)
	LoseMoney(money, serverconf.money_log.ticket)
end

local SendSelfMoneyToGame = function(body)
	Send("game", self.uid, cmd.EVENT_PLAYER_MONEY, self.money)
end

local SendBankerMoneyToGame = function(body)
	Send("game", self.uid, cmd.EVENT_BANKER_MONEY, self.money)
end

local UpdateGameconf = function(body)
	local conf = body[2]
	if self.roomid then
		roomconf = conf
		Send("player", self.uid, cmd.SMSG_UPDATE_ROOMCONF, conf.basebet, conf.minmoney, conf.choicepokertime)
	end
end

local Relogin = function(body)
	local _, sid, address, packtype = unpack(body)
	client = address
	sessionid = sid
	ptype = packtype
	connected = true
	self.login = true
	skynet.sleep(50) -- 重连时，给watchdog.lua中[EVENT_REDIRECT]中的操作预留足够时间
	if self.seatid then
		ChangeState(agent_state.be_seated)
	elseif self.roomid then
		ChangeState(agent_state.at_room)
	else
		ChangeState(agent_state.login_succ)
	end
	skynet.sleep(50)
	local roomid = 0
	if self.roomid then
		roomid = self.roomid
	end
	local title = Call("mysql", nil, cmd.SQL_GET_TITLE, self.score)
	local vip = GetSelfVip()
	if not self.firstbuy then
		local res = Call("mysql", nil, cmd.SQL_FIRST_BUYER, self.uid)
		if res then
			if #res ~= 0 then
				self.firstbuy = 1
			else
				self.firstbuy = 0
			end
		end
	end
	Send("player", self.uid, cmd.SMSG_LOGIN_SUCC, roomid, self.money, vip, 0, self.score, self.wincount, self.losecount,
	self.drawcount, self.monthwin, self.monthlose, self.monthdraw, title, 0, 0, 0, false, false, self.qq_vip, math.floor(self.dtmoney) / 10, self.firstbuy)
	SendNotice()
	CurTaskconf()
	GetTopList(3)
	if self.protect >= task.count[task.id.protect] and self.money < minmoney_fastenter then
		self.redpackettime = self.redpackettime + tonumber(os.time()) - self.redstarttime
		local time = CheckRedPacketTime()
		Send("player", self.uid, cmd.SMSG_RED_PACKET, time)
		self.redstarttime = tonumber(os.time())
	end
	WriteLog(cmd.DAY_LOG, "relogin")
end

local AdminAddMoney = function(body)
	local _, addid, money = unpack(body)
	local tellplayer = false
	if money >= 0 then
		AddMoney(money, addid)
		tellplayer = true
	elseif not self.lockmoney then
		if self.money >= -money then
			AddMoney(money, addid)
			tellplayer = true
		end
	end
	if tellplayer then
		if self.roomid then
			Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, addid, money, 0)
		else
			Send("player", self.uid, cmd.SMSG_ADD_MONEY, self.uid, addid, money, 0)
		end
	end
	skynet.ret(skynet.pack(tellplayer))
end

local AdminAddDtmoney = function(body)
	local _, addid, dtmoney = unpack(body)
	dtmoney = 10 * dtmoney
	local tellplayer = false
	if dtmoney >= 0 then
		AddDtmoney(dtmoney, addid)
		tellplayer = true
	elseif not self.lockmoney then
		if self.dtmoney >= -dtmoney then
			AddDtmoney(dtmoney, addid)
			tellplayer = true
		end
	end
	if tellplayer then
		if self.roomid then
			Broadcast(true, cmd.SMSG_ADD_MONEY, self.uid, addid, 0, 0)
		else
			Send("player", self.uid, cmd.SMSG_ADD_MONEY, self.uid, addid, 0, 0)
		end
	end
	skynet.ret(skynet.pack(tellplayer))
end

local AdminChangeSafeBoxPWD = function(body)
	local _, msg = unpack(body)
	if self.safebox then
		self.safebox.pwd = msg.pwd
	end
end

local GetShopResult = function(body)
	local _, conf, insertid = unpack(body)
	self.firstbuy =	conf.firstbuy
	if conf.money and conf.money ~= 0 then
		self.money = self.money + conf.money
		if self.money > minmoney_fastenter then
			self.redpackettime = 0
			self.redstarttime = 0
		end
	end
	if conf.todb then
		InitSelfTools(false)
	end
	if self.roomid then
		Broadcast(true, cmd.SMSG_SHOP, conf.uid, conf.fid, conf.goodsid, conf.count, conf.money, 0, self.vip, tonumber(math.floor(cowprice) / 10))
	else
		Send("player", self.uid, cmd.SMSG_SHOP, conf.uid, conf.fid, conf.goodsid, conf.count, conf.money, 0, self.vip, tonumber(math.floor(cowprice) / 10))
	end
end

local GrabBanker = function(body)
	local sign = MSG.upack(cmd.CMSG_SOME_ONE_GRAB, body)
	Send("game", nil, cmd.CMSG_SOME_ONE_GRAB, sign, self.money)
end

local ShutDown = function(body)
	if self.lock then
		return
	end
	if self.roomid then
		self.lock = true
		local ret = BlockCall("game", nil, cmd.CMSG_TRY_QUIT)
		self.lock = false
		if ret then
			connected = false
			Exit()
		end
	else
		connected = false
		Exit()
	end
end

local HeartBet = function(body)
	Send("player", self.uid, cmd.SMSG_HEART_BEAT)
	hearttimer:remove()
	hearttimer:start(4500, HeartBetCB)
end

local TopList = function(body)
	local topid = MSG.upack(cmd.CMSG_GET_TOP_LIST, body)
	GetTopList(topid)
end

local HonorList = function(body)
	local _ = MSG.upack(cmd.CMSG_GET_HONOR_LIST, body)
	GetHonorList()
end

local GetCowGoodsPrice = function(cowgoodsid)
	price = Call("shop", nil, cmd.EVENT_GET_COWPRICE, cowgoodsid)
	if price == 0 then
		Send("log", nil, cmd.ERROR_LOG, "Exchange goods error")
	else
		return price
	end
end

local CowExchangeMoney = function(body)
	local goodsid, platform, count = MSG.upack(cmd.CMSG_EXCHANGE_MONEY, body)
	cowprice = 10 * GetCowGoodsPrice(goodsid)
	local conf = {
		uid = tonumber(self.uid),
		fid = tonumber(self.uid),
		goodsid = tonumber(goodsid),
		count = tonumber(count),
		notice = tonumber(1) -- 1 表示不通知玩家
	}
	if self.dtmoney >= cowprice then
		local dtmoney = cowprice
		local id = task.id.exdtmoney
		LoseDtmoney(dtmoney, id)
		local msg = {uid = self.uid, platform = platform, goodsid = goodsid, price = math.floor(cowprice) / 10, num = count, money = math.floor(cowprice) / 10, suid = self.uid, status = 1, time = os.time()}
		local succ = skynet.call("Shop", "lua", cmd.EVENT_SHOP, conf)
		if not succ then
			AddDtmoney(dtmoney, id)
			WriteLog(cmd.DAY_LOG, "Cow exchange money failed")
		else
			Send("mysql", nil, cmd.SQL_INSERT_EXCHANGE_INFO, msg)
			WriteLog(cmd.DAY_LOG, "Cow exchange money succ")
		end
	end
end

local allways_run = {
	[cmd.CMSG_GET_LAST_LIST]		= GetLastHonorList,
	[cmd.CMSG_GET_TOP_LIST]			= TopList,
	[cmd.CMSG_GET_HONOR_LIST]		= HonorList,
	[cmd.CMSG_HEART_BEAT]			= HeartBet,
	[cmd.CMSG_GET_TASK_REWARD]		= GetTaskReward,
	[cmd.CMSG_USE_TOOL]				= UseTool,
	[cmd.CMSG_BROADCAST]			= PlayerBroadcast,
	[cmd.CMSG_GOODS_DESCRIBE]		= GetGoodsDescribe,
	[cmd.CMSG_SYSTEM_ERROR]			= SystemError,
	[cmd.CMSG_TASK_NEW_PLAYER]		= TaskNewPlayer,
	[cmd.CMSG_SELF_TOOLS_CONF]		= SelfToolConf,
	[cmd.CMSG_GET_PLAYER_GAMEINFO]	= GetPlayerGameInfo,
	[cmd.CMSG_SB_CHANGE_QUESTION]	= ChangeSafeBoxQuestion,
	[cmd.CMSG_SAFE_BOX_CHANGE_PWD]	= ChangeSafeBoxPWD,
	[cmd.CMSG_GET_PWD]				= GetSafeBoxPwd,
	[cmd.CMSG_COIN_SAFE_BOX]		= DealSafeBoxCoin,
	[cmd.CMSG_LOGIN_SAFE_BOX]		= LoginSafeBox,   
	[cmd.CMSG_GET_SAFE_BOX]			= GetSafeBox,
	[cmd.CMSG_CREAT_SAFE_BOX]		= CreatSafeBox,
	[cmd.CMSG_DEL_FRIEND]			= DelFriend,
	[cmd.CMSG_ADD_FRIEND]			= AddFriend,
	[cmd.CMSG_FACE]					= SendFace,
	[cmd.CMSG_CHAT_TO]				= ChatTo,
	[cmd.CMSG_UPDATE_FRIEND]		= UpdateFriend,
	[cmd.CMSG_EXCHANGE_MONEY]		= CowExchangeMoney,
	[cmd.CMSG_CHOICE_FRIEND_DEMAND] = ChoiceDemandFriend,
	[cmd.CMSG_REPLY_DEMAND_MONEY]	= ReplyDemandMoney,
	[cmd.CMSG_GET_FRIEND_MONEY_SUCC] = GetSelfDataAgain,
	[cmd.CMSG_GET_ONLINE]			= GetOnline,
	[cmd.CMSG_GET_ONLINEINFO]		= GetOnlineInfo,
	[cmd.CMSG_GET_SCRATCH_REWARD]	= Scratch,
	[cmd.CMSG_GET_REDPACKET_REWARD] = RedPacket,
}

command[agent_state.connected] = {
	[cmd.CMSG_LOGIN]				= Login
}

command[agent_state.login_in] = {}
command[agent_state.login_succ] = {
	[cmd.CMSG_TABLE_GETALL]		= GetRoomList,
--	[cmd.CMSG_BAKER_ENTER]		= BankerEnter,
	[cmd.CMSG_FAST_ENTER]		= PlayerFastEnter,
	[cmd.CMSG_ENTER_ROOM]		= EnterRoom,
	[cmd.CMSG_LOGIN_OUT]		= LoginOut
}

command[agent_state.enter_room] = {}
command[agent_state.at_room] = {
	[cmd.CMSG_CHANGE_ROOM]		= ChangeRoom,
	[cmd.CMSG_ROOM_CHAT]		= ChatAtRoom,
	[cmd.CMSG_TRY_QUIT]			= TryQuit,
--	[cmd.CMSG_QUIT_ROOM]		= QuitRoom,
	[cmd.CMSG_ENTER_ROOM]		= EnterRoom,
	[cmd.CMSG_SIT]				= Sit
}

command[agent_state.sit_down] = {
}

command[agent_state.be_seated] = {
	[cmd.CMSG_BET]				= Bet,
	[cmd.CMSG_CHANGE_ROOM]		= ChangeRoom,
	[cmd.CMSG_ROOM_CHAT]		= ChatAtRoom,
	[cmd.CMSG_CHOICE_SP_TYPE]	= ChoiceSPType,
	[cmd.CMSG_CHOICE_POKER]		= ChoicePokerType,
	[cmd.CMSG_CHANGE_POKER]		= ChangePoker,
	[cmd.CMSG_TRY_STAND]		= TryStand,
	[cmd.CMSG_TRY_QUIT]			= TryQuit,
--	[cmd.CMSG_QUIT_ROOM]		= QuitRoom,
--	[cmd.CMSG_STAND]			= Stand,
	[cmd.CMSG_SOME_ONE_GRAB]	= GrabBanker,
	[cmd.CMSG_ENTER_ROOM]		= EnterRoom,
	[cmd.CMSG_BF_POKER_TYPE]	= BFChoicePokerType
}
command[agent_state.stand_up] = {}
command[agent_state.quit_room] = {}
command[agent_state.login_out] = {}
command[agent_state.disconnect] = {}

local event = {
	[cmd.EVENT_SHUT_DOWN]				= ShutDown, 
	[cmd.EVENT_SHOP]					= GetShopResult,
	[cmd.EVENT_ADMIN_CHANGE_SF_PWD] 	= AdminChangeSafeBoxPWD,
	[cmd.EVENT_ADMIN_ADD_MONEY]			= AdminAddMoney,
	[cmd.EVENT_ADMIN_ADD_DTMONEY]		= AdminAddDtmoney,
	[cmd.EVENT_RELOGIN]					= Relogin,
	[cmd.EVENT_UPDATE_GAMECONF]			= UpdateGameconf,
	[cmd.EVENT_A_NEW_DAY]				= NoticeTime,
	[cmd.EVENT_KICK_FOR_GAME_OVER]		= KickForGameOver,
	[cmd.EVENT_SOME_ONE_QUIT]			= SomeOneQuit,
	[cmd.EVENT_SOME_ONE_STAND]			= SomeOneStand,
	[cmd.EVENT_SOME_ONE_SIT]			= SomeOneSit,
	[cmd.EVENT_KICK]					= Kick,
	[cmd.EVENT_SOME_ONE_ENTER]			= SomeOneEnter,
	[cmd.EVENT_NOTIFY_LOSER_GET_RESULT]	= LoserGetResult,
	[cmd.EVENT_ADD_MONEY]				= EventAddMoney, 
	[cmd.EVENT_PLAY_ONE_MATCH]			= PlayOneMatch,
	[cmd.EVENT_GET_PLAYER_GAMEINFO] 	= GetGameInfo,
	[cmd.EVENT_TAKE_FEE]				= TakeFee,
	[cmd.EVENT_GET_MONEY]				= SendSelfMoneyToGame,
	[cmd.EVENT_GET_BANKER_MONEY]		= SendBankerMoneyToGame
}

skynet.register_protocol{
	name = "websocket",
	id = 111,
	pack = function(...) return ... end,
	unpack = function(...) return ... end
}

skynet.register_protocol{
	name = "client", 
	id = 3,
	pack = function(...) return  ... end,
	unpack = function(...)		
		return MSG.upack("packet", ...)
	end,
	dispatch = function (session, address, type, body)
		if allways_run[tonumber(type)] and self.login then
			allways_run[tonumber(type)](body)
		elseif command[cur_state] then
			f = command[cur_state][tonumber(type)]
			if f then
				f(body)
			else
				print("Unknow client command:", type)
			end
		else 
			print("player haven't login", self.login, sessionid)
		end
	end
}

skynet.register_protocol{
	name = "relay",
	id = 20,
	pack = function(...) return ... end,
	unpack = function(...) return ... end,
	dispatch = function (session, address, msg, sz)
		Send("player", self.uid, nil, skynet.tostring(msg, sz))
	end
}

skynet.register_protocol{
	name = "game",
	id = 100,
	pack = function(...)  return skynet.pack(self.roomid, self.uid, ...) end,
	unpack = function(...) return skynet.unpack(...) end,
	dispatch = function(session, address, type, body)
		print("recv game message:", body)
		local f = command[tonumber(type)]
		if f then
			f(body)
		else
			print("unknow game command:", type)
		end
	end
}

skynet.start(function()
	skynet.error("Start cpagent")
	skynet.dispatch("text", function(session, address, text)
		print("recv text message:", text)
		if text == "CLOSE" then
			peer_close()
		end
	end)
	skynet.dispatch("lua", function(session, address, ...)
		local t = {...}
		local mtype = t[1]
		t[1] = address
		print("recv lua message:", mtype)
		local f = event[tonumber(mtype)]
		if f then
			f(t)
		else
			print("unknow lua command:", type)
		end
	end)
	hearttimer:start(4000, HeartBetCB)
end)
