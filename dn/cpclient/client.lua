local skynet = require "skynet"
require"cmd"
local cmd = CMD
local casino = require "poker"
local timer = require"timer"
local serverconf = require"serverconf"
local mytimer = timer.new()
local hearttimer = timer.new()

print"start test"
local socket = require"socket"
require"gameprotobuf"
local protobuf = protobuf
local table = table
local pairs = pairs
local ipairs = ipairs
local GP = protobuf.proto.game.package

local command = {}
local self = {}
local curstate = 1
local rooms = {}
local havechoice = false
--local ingame = false
local siternum = 0
local seater = {}

math.randomseed(os.time())

local states = {
	S_CONNECT		= 1,
	S_LOGIN			= 2,
	S_ENTER			= 3,
	S_IN_ROOM		= 4,
	S_SIT			= 5,
	S_GRAB			= 6,
	S_BET			= 7,
	S_WAIT_DEAL_POKER = 8,
	S_CHOICE_POKER	= 9,
	S_QUIT			= 10,
	S_DISCONNECT	= 11,
}


local function ChangeState(state)
	curstate = state
end

self.uid = ...
self.uid = tonumber(self.uid)
local act = {}
local send = function(body, type)
	if type then
		body = protobuf.pack(GP..".Packet type body", type, body)
	end
	socket.writeblock(2, body)
end

local print = function(...)
	print("["..self.uid.."]",...)
end

act.LoginOut = function()
	print("*****act.LoginOut")
	local body = protobuf.pack(GP..".CMSG_LOGIN_OUT")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_LOGIN_OUT, body)
	send(packet)
end

act.Login = function(uid)
	print("*******act.Login")
	local uinfo = skynet.call("rbDB", "lua", "GET_USERINFO", self.uid)
	local key = "serverrobot"
	local body = protobuf.pack(GP..".CMSG_LOGIN uid key info", uid, key, uinfo)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_LOGIN, body)
	send(packet)
end

act.FastEnter = function(roomtype)
	print("*****FastEnter", self.uid)
	self.roomtype = roomtype
	local body = protobuf.pack(GP..".CMSG_FAST_ENTER roomtype gametype", roomtype, 11)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_FAST_ENTER, body)
	send(packet)
end

act.ChangeRoom = function()
	print("*****ChangeRoom", self.uid)
	local body = protobuf.pack(GP..".CMSG_CHANGE_ROOM")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_CHANGE_ROOM, body)
	send(packet)
end

act.EnterRoom = function(roomid)
	print("******act.EnterRoom", self.uid)
	local body = protobuf.pack(GP..".CMSG_ENTER_ROOM roomid", roomid)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_ENTER_ROOM, body)
	send(packet)
end

act.TableGetAll = function(roomtype)
	print("*****act.TableGetAll", self.uid)
	local body = protobuf.pack(GP..".CMSG_TABLE_GETALL type", roomtype)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_TABLE_GETALL, body)
	send(packet)
end

act.Sit = function(seatid)
	print("******act.Sit", self.uid)
	local body = protobuf.pack(GP..".CMSG_SIT seatid", seatid)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_SIT, body)
	send(packet)
end

act.Stand = function()
	print("*****act.Stand", self.uid)
	local body = protobuf.pack(GP..".CMSG_STAND")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_STAND, body)
	send(packet)
end

act.Quit = function()
	print("*****act.Quit", self.uid)
	local body = protobuf.pack(GP..".CMSG_QUIT_ROOM")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_QUIT_ROOM, body)
	send(packet)
end

act.TryQuit = function()
	print("*****act.TrtQuit", self.uid)
	local body = protobuf.pack(GP..".CMSG_TRY_QUIT")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_TRY_QUIT, body)
	send(packet)
end

act.TryStand = function()
	print("*****act.TrtStand", self.uid)
	local body = protobuf.pack(GP..".CMSG_TRY_STAND")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_TRY_STAND, body)
	send(packet)
end

act.Grab = function()
	print("*****act.Grab")
	local random = math.random(1, 5)
	if random == 3 or random == 1 then
		sign = 1
	else
		sign = 2
	end
	local body = protobuf.pack(GP..".CMSG_SOME_ONE_GRAB sign", sign)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_SOME_ONE_GRAB, body)
	send(packet)
end

act.Bet = function(betmoney)
	print("*****act.Bet")
	local body = protobuf.pack(GP..".CMSG_BET betmoney", betmoney)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_BET, body)
	send(packet)
end

act.BfPokerType = function()
	print("*****act.BfPokerType")
	local cards = {}
	for k, v in pairs(self.choicecards) do
		local card = protobuf.pack(GP..".card point suit", v.point, v.suit)
		table.insert(cards, card)
	end
	if not self.pokertype then
		skynet.error(".........................self.uid=" .. self.uid)
	end
	local body = protobuf.pack(GP..".CMSG_BF_POKER_TYPE pokertype cards", self.pokertype, cards)
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_BF_POKER_TYPE, body)
	send(packet)
end

act.HeartBeat = function()
	print("*****act.HeartBeat")
	local body = protobuf.pack(GP..".CMSG_HEART_BEAT")
	local packet = protobuf.pack(GP..".Packet type body", cmd.CMSG_HEART_BEAT, body)
	send(packet)
end

local function StartHeart()
	act.HeartBeat()
	hearttimer:start(3000, StartHeart)
end

local function QuitOrStand()
	print("*****QuitOrStand")
	local r = math.random(1, 60)
--	skynet.timeout(r * 100, function()
		local rand = math.random(1, 2)
		if rand == 1 then
			act.TryStand()
		elseif rand == 2 then
			act.TryQuit()
		end
--	end)
end

act[states.S_CONNECT] = function()
	act.Login(self.uid)
end

--local uids = {6, 7, 8, 9}
--local uids = {10, 11, 12, 13}
local uids2 = {{5, 31},{32, 61},{62, 91}} --机器人uid
act[states.S_LOGIN] = function()
	siternum = 0
	seater[self.uid] = nil
	print("*****S_LOGIN", self.uid)
	--[[
	if self.uid == uids[1] then
		self.roomtype = 1
	elseif self.uid == uids[2] then
		self.roomtype = 2
	elseif self.uid == uids[3] then
		self.roomtype = 3
	else
		self.roomtype = 4
	end
	]]
	if self.uid >= uids2[1][1] and self.uid <= uids2[1][2] then
		self.roomtype = 1
	elseif self.uid >= uids2[2][1] and self.uid <= uids2[2][2] then
		self.roomtype = 2
	elseif self.uid >= uids2[3][1] and self.uid <= uids2[3][2] then
		self.roomtype = 3
	end

	act.TableGetAll(self.roomtype)
end

act[states.S_ENTER] = function()
	act.EnterRoom(self.roomid)
end

act[states.S_IN_ROOM] = function()
	print("*****S_IN_ROOM", self.uid)
	local seatid = math.random(0, 5)
--	if siternum == 1 then
--	if siternum <= 2 then
	local rand = math.random(1, 4)
	if siternum <= rand then
		act.Sit(seatid)
	else
		ChangeState(states.S_QUIT)
	end
end


act[states.S_SIT] = function()
	print("*****S_SIT", self.uid)
	if siternum == 1 and seater then
		for k, v in pairs(seater) do
			if k == self.uid then
				ChangeState(states.S_QUIT)	
			end
		end
	end
end

act[states.S_QUIT] = function()
	print("*****S_QUIT", self.uid)
	act.TryQuit()
end

local havebet = false
act[states.S_BET] = function()
	print("**...***S_BET", self.uid)
	local result = skynet.call("rbDB", "lua", "GET_ROOMINFO", self.roomid)
	local res = unpack(result)
	if res and #res ~= 0 then
		self.basebet = res[2]
	end
	local j = math.random(1, 10)
	local basenum = {1, 3, 7, 10} -- 下注的倍数
	if j > 0 and j < 6 then i = basenum[4]
	elseif j >= 6 and j < 8 then i = basenum[3]
	elseif j > 8 and j < 10 then i = basenum[2]
	else i = basenum[1] end
	local betmoney = self.basebet * i
--	if ingame and not havebet then
	if seater[self.uid] and not havebet then
		act.Bet(betmoney)
		havebet = true
	else
		act.TryQuit()
	end
end

act[states.S_WAIT_DEAL_POKER] = function()

end

act[states.S_CHOICE_POKER] = function()
	print("*****S_CHOICE_POKER")
	havebet = false
	if siternum == 1 and seater[self.uid] then
		act.TryQuit()	
	end
--	if not havechoice and ingame then
	if not havechoice and seater[self.uid] then
		act.BfPokerType()
		havechoice = true
	end
end

local havegrab = false
act[states.S_GRAB] = function()
	print("*****S_GRAB", self.uid)
--	if ingame and not havegrab then
	if seater[self.uid] and not havegrab then
		act.Grab()
		havegrab = true
	end
end

act[states.S_DISCONNECT] = function()
	print("*****S_DISCONNECT")
	if socket.connect("10.4.7.243:8004") then
		print("Connect to server failed")
	else
		print("Connected to server")
		hearttimer:start(3000, StartHeart)
		ChangeState(states.S_CONNECT)
	end
end

command[cmd.SMSG_LOGIN_SUCC] = function(body)
	print("uid " .. self.uid .. " 登陆成功 SMSG_LOGIN_SUCC")
	local _, money = protobuf.unpack(GP..".SMSG_LOGIN_SUCC roomid money", body)
	self.money = money
	print("self.money ", self.money)
	ChangeState(states.S_LOGIN)
end

command[cmd.SMSG_LOGIN_FAILD] = function(body)
	local errcode = protobuf.unpack(GP..".SMSG_LOGIN_FAILD errcode", body)
	print("login failed, errcode = ", errcode)
end

--返回房间列表
command[cmd.SMSG_TABLE_GETALL] = function(body)
	local _, roomids = protobuf.unpack(GP..".SMSG_TABLE_GETALL type tables", body)
	print("返回房间列表 SMSG_TABLE_GETALL", self.uid)
	for k, v in pairs(roomids) do
		local roomid, player_sit = protobuf.unpack(GP..".table tid tplayer", unpack(v))
		print("roomid = ", roomid, "player_sit = ", player_sit)
--		if player_sit == 1 then
		if player_sit <= 2 then
			self.roomid = roomid
			ChangeState(states.S_ENTER)
			break
		end
	end
end

--返回自己进入房间成功
command[cmd.SMSG_ENTER_ROOM_SUCC] = function(body)
	local roomid = protobuf.unpack(GP..".SMSG_ENTER_ROOM_SUCC roomid", body)
	print(self.uid .. "进入房间成功 SMSG_ENTER_ROOM_SUCC", roomid)
	ChangeState(states.S_IN_ROOM)
end


--返回某人进入房间(不包括自己)
command[cmd.SMSG_SOMEONE_ENTER] = function(body)
	local uid, info = protobuf.unpack(GP..".SMSG_SOMEONE_ENTER uid info", body)
	print("某人进入房间 SMSG_SOMEONE_ENTER", uid)
end

--返回自己进入房间失败
command[cmd.SMSG_ENTER_ROOM_FAILD] = function(body)
	print("进入房间失败 SMSG_ENTER_ROOM_FAILD", self.uid)
	local errcode = protobuf.unpack(GP..".SMSG_ENTER_ROOM_FAILD errcode", body)
	print("enter room faild", errcode, "roomid = ", self.roomid)
	ChangeState(states.S_ENTER)
end


--返回某人坐下(包括自己)
command[cmd.SMSG_SOMEONE_SIT] = function(body)
	local seaters = protobuf.unpack(GP..".SMSG_SOMEONE_SIT seaters", body)
	for k, v in pairs(seaters) do
		local uid, seatid = protobuf.unpack(GP..".seater uid seatid", unpack(v))
		seater[uid] = true
		siternum = siternum + 1
		print("uid " .. uid .." 坐下 SMSG_SOMEONE_SIT")
		if uid == self.uid then
			self.seatid = seatid
			print("Sit at ", seatid)
			ChangeState(states.S_SIT)
		else
			print("player",  uid, "sit at", seatid)
		end
	end
end

command[cmd.SMSG_UP_GAME_DATA] = function(body)

end

--返回坐下失败
command[cmd.SMSG_SIT_FAILD] = function(body)
	print("坐下失败 MSG_SIT_FAILD", self.uid)
	local errcode = protobuf.unpack(GP..".SMSG_SIT_FAILD errcode", body)
	print("sit faild", errcode)
	if errcode == 17 then
		self.nomoney = true
		ChangeState(states.S_QUIT)
	elseif errcode == 200 then
		self.muchmoney = true
		ChangeState(states.S_QUIT)
	else
		ChangeState(states.S_QUIT)
	end
end

command[cmd.SMSG_SOMEONE_STAND] = function(body)
	local uid, seatid = protobuf.unpack(GP..".SMSG_SOMEONE_STAND uid seatid", body)
	print("站起 SMSG_SOMEONE_STAND", uid)
	if seater[uid] then
		siternum = siternum - 1
		seater[uid] = nil
	end
	if uid == self.uid then
--		ingame = false
		self.seatid = nil
		print("stand from seat", seatid)
		ChangeState(states.S_QUIT)
	else
		print("player", uid, "stand from",  seatid)
	end
end

command[cmd.SMSG_STAND_FAILD] = function(body)
	local errcode = protobuf.unpack(GP..".SMSG_STAND_FAILD errcode", body)
	print(self.uid.."stand failed......", errcode)
end

command[cmd.SMSG_QUIT_FAILD] = function(body)
	local errcode = protobuf.unpack(GP..".SMSG_QUIT_FAILD errcode", body)
	print(self.uid.."quit failed .....", errcode)
end

command[cmd.SMSG_TIMEOUT_KICK] = function(body)
	print("两局超时自动站起 SMSG_TIMEOUT_KICK", self.uid)
--	ingame = false
	ChangeState(states.S_QUIT)
end

local money_add = {10000, 30000, 320000, 500000}
local addmoney = function()
	local changemoney = 0
	--[[
	if self.uid == uids[1] then
		changemoney = money_add[1] - self.money
	elseif self.uid == uids[2] then
		changemoney = money_add[2] - self.money
	elseif self.uid == uids[3] then
		changemoney = money_add[3] - self.money
	end
	]]
	if self.uid >= uids2[1][1] and self.uid <= uids2[1][2] then
		changemoney = money_add[1] - self.money
	elseif self.uid >= uids2[2][1] and self.uid <= uids2[2][2] then
		changemoney = money_add[2] - self.money
	elseif self.uid >= uids2[3][1] and self.uid <= uids2[3][2] then
		changemoney = money_add[3] - self.money
	end
		local msg = {uid = self.uid, money = changemoney}
		local param = {uid = self.uid, money = changemoney, curmoney = self.money + changemoney, typeid = serverconf.money_log.robot_addmoney}
		skynet.send("rbDB", "lua", "MONEY_LOG_ROBOT", param)
		skynet.send("rbDB", "lua", "ADD_MONEY_ROBOT", msg)
end

local function TimerCallBack()
	local f = act[curstate]
	if f then
		f()
	end
	mytimer:start(300, TimerCallBack)
end

command[cmd.SMSG_SOMEONE_QUIT] = function(body)
	local uid = protobuf.unpack(GP..".SMSG_SOMEONE_QUIT uid", body)
	print("退出房间 SMSG_SOMEONE_QUIT", uid)
	if seater[uid] then
		siternum = siternum - 1
		seater[uid] = nil
	end
	if uid == self.uid then
--		ingame = false
		self.roomid = nil
		self.seatid = nil
		rooms = {}
		if self.nomoney or self.muchmoney then
			self.nomoney = false
			self.muchmoney = false
			mytimer:remove()
			hearttimer:remove()
			socket.close()
			addmoney()
			ChangeState(states.S_DISCONNECT)
			mytimer:start(1000, TimerCallBack)
		else
			ChangeState(states.S_LOGIN)
		end
	else
		print("player", uid, "quit")
	end
end

command[cmd.SMSG_LOGOUT_SUCC] = function(body)
	print("logout succ", self.uid)
end

command[cmd.SMSG_TAKE_FEE] = function(body)
	local uids, playerfee, bankerfee = protobuf.unpack(GP..".SMSG_TAKE_FEE uids money bankerfee", body)
	print("收取房间服务费 SMSG_TAKE_FEE", self.uid, uids)
	for k, v in pairs(uids) do
		if v == self.uid then
			if self.uid == self.bankeruid then
				self.money = self.money - bankerfee
			else
				self.money = self.money - playerfee
			end
		end
	end
end

command[cmd.SMSG_DEAL_POKER] = function(body)
	print("开始发牌 SMSG_DEAL_POKER", self.uid)
	havechoice = false
	local card1 = protobuf.unpack(GP..".SMSG_DEAL_POKER cards", body)
	local cards = {}
	for k, v in pairs(card1) do
		local point, suit = protobuf.unpack(GP..".card point suit", unpack(v))
		local card = {point = point, suit = suit}
--		print("card.point = ", card.point, "card.suit = ", card.suit)
		table.insert(cards, card)
	end
	self.cards = cards

	local rettype = {}
	if not self.choicecards then
		self.choicecards = {}
	end
	if #cards == 5  then
		self.pokertype = casino.GetBFType(cards, rettype)
		casino.CopyCards(rettype, self.choicecards)
	else
		self.pokertype = 0
	end
	if not self.pokertype then
		skynet.error("...................#cards=" .. #cards .. "self.uid=" .. self.uid)
	end
end

--开始理牌
command[cmd.SMSG_CHOICE_POKER] = function(body)
	print("开始理牌 SMSG_CHOICE_POKER", self.uid)
--	if ingame then
	if seater[self.uid] then
		ChangeState(states.S_CHOICE_POKER)
	end
end

--游戏结束
command[cmd.SMSG_GAME_OVER] = function(body)
	print("本局游戏结束 SMSG_GAME_OVER", self.money)
--	ingame = false
--	if siternum >= 3 then
	local rand = math.random(3, 5)
	if siternum >= rand then
		ChangeState(states.S_QUIT)	
	end
end

--提前结算
command[cmd.SMSG_GAME_OVER_AHEAD] = function(body)
	print("提前结算 SMSG_GAME_OVER_AHEAD")
--	ingame = false
end


--游戏公告命令
command[cmd.SMSG_UPDATE_NOTICE] = function(body)

end

--登陆获取任务信息
command[cmd.SMSG_TASKCONF] = function(body)

end

--更新排行榜数据
command[cmd.SMSG_TOP_LIST] = function(body)

end

--恢复游戏数据
command[cmd.SMSG_BF_RESUME_GAME] = function(body)

end

--广播亮牌结果
command[cmd.SMSG_BF_SOME_ONE_CHOICE] = function(body)
	local uid , succ, cardstype, cards = protobuf.unpack(GP..".SMSG_BF_SOME_ONE_CHOICE uid succ cardstype cards", body)
	print("广播亮牌结果 SMSG_BF_SOME_ONE_CHOICE", uid, succ, cardstype)
end

--返回比牌结果
command[cmd.SMSG_BF_SHOW_RESULT] = function(body) 
	print("返回比牌结果 SMSG_BF_SHOW_RESULT", self.uid)
	local lastresults = protobuf.unpack(GP..".SMSG_BF_SHOW_RESULT results", body)
	for k, v in pairs(lastresults) do
		local uid, totaladd, winmoney, _, _ = protobuf.unpack(GP..".bf_result uid totaladd winmoney pokertype cards", unpack(v))
		if uid == self.uid then
			self.money = self.money + winmoney
		end
	end
end

--游戏开始
command[cmd.SMSG_BF_GAME_START] = function(body)
	print("游戏开始 SMSG_BF_GAME_START", self.uid)
	local playernum_ingame, uids = protobuf.unpack(GP..".SMSG_BF_GAME_START players uids", body)
	for k, v in pairs(uids) do
		if v == self.uid then
--			ingame = true
		end
	end
end

--开始下注
command[cmd.SMSG_NOTIFY_BET] = function(body)
	havegrab = false
	print("开始下注 SMSG_NOTIFY_BET", self.uid)
		if self.bankeruid == self.uid then
			ChangeState(states.S_WAIT_DEAL_POKER)
		else
			ChangeState(states.S_BET)
		end
end

--广播某人下注状态
command[cmd.SMSG_SOME_ONE_BET] = function(body)
--	print("SMSG_SOME_ONE_BET", self.uid)
end

--通知玩家庄家ID
command[cmd.SMSG_NOTIFY_THE_BANKER] = function(body)
	local bankeruid, _= protobuf.unpack(GP..".SMSG_NOTIFY_THE_BANKER uid type", body)
	self.bankeruid = bankeruid
	print("通知玩家庄家ID", bankeruid)
end

--通知开始抢庄
command[cmd.SMSG_GRAB_BANKER] = function(body)
	print("通知开始抢庄 SMSG_GRAB_BANKER", self.uid)
--	if ingame then
	if seater[self.uid] then
		ChangeState(states.S_GRAB)
	end
end

--通知其他玩家某玩家是否抢庄
command[cmd.SMSG_SOME_ONE_GRAB_BANKER] = function(body)
	print("SMSG_SOME_ONE_GRAB_BANKER", self.uid)
end

command[cmd.SMSG_PLAY_ONE_MATCH] = function(body)
	print("SMSG_PLAY_ONE_MATCH", self.uid)
end

command[cmd.SMSG_ROOM_CHAT] = function(body)

end

command[cmd.SMSG_ADD_MONEY] = function(body)

end

command[cmd.SMSG_HEART_BEAT] = function(body)

end
--local function StartHeart()
--	skynet.timeout(300, function()
--		act.HeartBeat()
--		StartHeart()
--	end)
--end


skynet.register_protocol{
	name = "client",
	id = 3,
	pack = function(...) return ... end,
	unpack = function(...) return ... end,
	dispatch = function(session, address, msg, sz)
		socket.push(msg, sz)
		while true do
			local ok = socket.readblock(2, function(msg, sz)
				local mtype, body = protobuf.unpack(GP..".Packet type body", msg, sz)
				local f = command[tonumber(mtype)]
--				local f = command[curstate][tonumber(mtype)]
				if f then
					f(body)
				else 
					print("Unknow command:", mtype, tostring(body))
				end
				return sz
			end)
			if not ok then
				break
			end
		end
	end
}

skynet.start(function()
--	skynet.dispatch("text", function(session, address, text)
--		local text, param = string.match(text, "(%w+) ?(.*)")
--		print(text, "request", param)
--		if text == "login" then
--			act.Login(param)
--		elseif text == "enter" then
--			act.EnterRoom(param)
--		elseif text == "sit" then
--			act.Sit(param)
--		elseif text == "stand" then
--			act.Stand()
--		elseif text == "quit" then
--			act.Quit()
--		else
--			print("Unknow command", text)
--		end
--	end)
	print("Start agent uid", self.uid)
	if socket.connect("10.4.7.243:8004") then
		print("Connect to server failed")
	else
		print("Connected to server")
	end
	skynet.register"CPCLIENT"
--	skynet.register(tostring(self.uid))
--	act.Login(self.uid)
	mytimer:start(300, TimerCallBack)
	hearttimer:start(300, StartHeart)
end)

--StartTimer()
--StartHeart()

--skynet.timeout(100,funtion() act.Login(self.uid) end)



