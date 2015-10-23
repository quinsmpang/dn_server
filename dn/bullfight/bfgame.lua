local skynet = require "skynet"
local cmd = require "cmd"
local casino = require "poker"
local types = require "types"
local error = require "errorcode"
local table = table
local string = string
local pairs = pairs
local print = print
local timer = require "timer"
local MSG = require "gamepacket" 
--local print =  function(...) end
local server_close = false
local all_games = {}
local command = {}
local timers = {}
local uplose = {}

local states = {
	WAIT_PLAYER				= 1,
	WAIT_START_GAME			= 2,
	GRAB_THE_BANKER			= 3,
	WAIT_BET				= 4,
	DEAL_POKER				= 5,
	CHOICE_POKER_TYPE		= 6,
	WAIT_SHOW_RESULT		= 7,
	SHOW_RESULT				= 8
}

local timerid = {
	T_WAIT_START			= 1,
	T_GRAB_BANKER			= 2,
	T_BET					= 3,
	T_DEAL_POKER			= 4,
	T_CHOICE_POKER			= 5,
	T_WAIT_SHOW_RESULT		= 6,
	T_SHOW_RESULT			= 7,
	T_CHECK_LOSTER			= 8,
	T_SHOW_BRANKER_RESON	= 9,
	T_WAIT_BET				= 10
}

local playerstate = {
	GRAB_BANKER				= 1,
	STATE_BET				= 2,
	GET_DEAL_POKER			= 3,
	CHOICE_POKER			= 4,
	WAIT_COMPARE			= 5
}

local function ChangeState(game, state)
	game.curstate = state
end

local function GetGame(id)
	if not all_games[id] then
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("Get nil game %d", id))
	end
	return all_games[id]
end

local function InitPoker(game)
	casino.InitPoker(game.poker)
	casino.DisCard(game.poker, {point = 15, suit = 5})
	casino.DisCard(game.poker, {point = 16, suit = 5})
end

local function CreatGame(gameconf)
	local id = gameconf.roomid
	if not all_games[id] then
		all_games[id] = {
			id				= id,-- 表示房间id
			watcher			= {}, 
			seater			= {}, 
			gameplayer		= {}, 
			forcequitplayer = {},
			players			= {},
			sitnum			= 0,
			timers			= {},
			poker			= {},
			pos				= 1,
			curstate		= states.WAIT_PLAYER,
			updateconf		= nil,
			gameconf		= gameconf,
			havegetresult	= false,
			needgrabbanker  = true,
			topupling		= 1,
			banker			= 0,
			bankermoney		= 0,
			playcount		= 0,
			grabresontype	= 0,
			starttime		= 0,
			bankersourcetype	= 0,
			lastresult		= {},
			tablelog		= {cardsid = nil, count = 0, playersid = nil, log = "start"}
		}
		InitPoker(all_games[id])
	end
end

local function UpdateGameconf(game)
	if game.updateconf then
		game.gameconf = game.updateconf
		game.updateconf = nil
		for k, v in pairs(game.players) do
			skynet.send(v.address, "lua", cmd.EVENT_UPDATE_GAMECONF, game.gameconf)
		end
	end
end

local function SendTo(game, uid, msgtype, ...)
	local msg
	if msgtype then
		msg = MSG.pack(msgtype, ...)
	else
		msg = ...
	end
	local player = game.players[uid]
	if player then
--		skynet.send(player.address, "relay", msg)
		pcall(skynet.send, player.address, "relay", msg)
	end
end

local function Broadcast(game, exceptid, msgtype, ...)
	local msg
	if msgtype then
		msg = MSG.pack(msgtype, ...)
	else
		msg = ...
	end
	if game.players ~= nil then
		for k, v in pairs(game.players) do
			if exceptid then
				if exceptid ~= v.uid then
--					skynet.send(v.address, "relay", msg)
					pcall(skynet.send, v.address, "relay", msg)
				end
			else
--				skynet.send(v.address, "relay", msg)
				pcall(skynet.send, v.address, "relay", msg)
			end
		end
	end
end

local function TimerCB(gameid, timerid)
	local game = GetGame(gameid)
	if game then
		command[game.curstate](game, timerid, nil)
	end
end

local function AddTimer(gameid, timerid, waittime)
	waittime = waittime*100
	local game = GetGame(gameid)
	if game then
		if not game.timers then
			game.timers = {}
		end
		if not game.timers[timerid] then
			game.timers[timerid] = timer.new()
		end
		game.timers[timerid]:start(waittime, TimerCB, gameid, timerid)
	end
end

local function RemoveTimer(gameid, timerid)
	local game = GetGame(gameid)
	if game and game.timers then
		if timerid then
			if game.timers[timerid] then
				game.timers[timerid]:remove()
			end
		else
			for k, v in pairs(game.timers) do
				v:remove()
			end
		end
	end
end

local function IsGameStart(game)  
	if game.curstate == states.DEAL_POKER or
		game.curstate == states.GRAB_THE_BANKER or
		game.curstate == states.WAIT_BET or
		game.curstate == states.CHOICE_POKER_TYPE or
		game.curstate == states.WAIT_SHOW_RESULT then
		return true
	end
	return false
end

local function UpLose(roomid, uid, money)
	if not uplose[uid] then
		uplose[uid] = {}
		uplose[uid].sumlose = 0
	end
	if not uplose[uid][roomid] then
		uplose[uid][roomid] = {}
		uplose[uid][roomid].lose = 0
	end
	uplose[uid].sumlose = uplose[uid].sumlose + money
	uplose[uid][roomid].lose = uplose[uid][roomid].lose + money
end

local function AddMoney(game, uid, money)
	if game.players[uid] then
		pcall(skynet.send, game.players[uid].address, "lua", cmd.EVENT_ADD_MONEY, money, game.tablelog.cardsid)
	end
end

local function LoseMoney(game, uid, money) 
	if game.players[uid] then
		pcall(skynet.send, game.players[uid].address, "lua", cmd.EVENT_LOSE_MONEY, money)
	end
end

local function AddPlayerToGame(game)
	local num = 0
	game.tablelog.time = os.time()
	game.tablelog.cardsid = game.id .. game.tablelog.time
	game.gameplayer = {}
	for k, v in pairs(game.seater) do
		if game.gameplayer[k] == nil then
			game.gameplayer[k] = {
				uid			= v.uid,
				cards		= {},
				choicecards = {},
				pokertype	= -1,
				money		= 0,
				winmoney	= 0,
				totaladd	= 0,
				betmoney	= 0,
				grabbanker	= 0,
				havechoice  = false
			}
		end
		if not game.tablelog.playersid then
			game.tablelog.playersid = v.uid
		else
			game.tablelog.playersid = game.tablelog.playersid .. "," .. v.uid
		end
		num = num + 1
	end
	game.tablelog.count = num
	return num
end

local function GetCompareResult(game)
	local banker = game.gameplayer[game.banker]
	for k, v in pairs(game.gameplayer) do
		if k ~= banker.uid then
			local add = math.floor(v.betmoney / game.gameconf.basebet)
			if casino.BFCompare(v.choicecards, v.pokertype, banker.choicecards, banker.pokertype) then
				add = add * types.bulladd[v.pokertype]
				v.totaladd = v.totaladd + add
				banker.totaladd = banker.totaladd - add
			else
				add = math.floor(add * types.bulladd[banker.pokertype])
				v.totaladd = v.totaladd - add
				banker.totaladd = banker.totaladd + add
			--	skynet.send(game.players[v.uid].address, "lua", cmd.EVENT_NOTIFY_LOSER_GET_RESULT)
				pcall(skynet.send, game.players[v.uid].address, "lua", cmd.EVENT_NOTIFY_LOSER_GET_RESULT)
			end
		end
	end
	game.bankermoney = 0
--	skynet.send(game.players[banker.uid].address, "lua", cmd.EVENT_GET_BANKER_MONEY)
	pcall(skynet.send, game.players[banker.uid].address, "lua", cmd.EVENT_GET_BANKER_MONEY)
end

local function NotifyPlayerChoicePoker(game) 
	Broadcast(game, nil, cmd.SMSG_CHOICE_POKER, 0)
end

local function DealChangePoker(game)
	ChangeState(game, states.DEAL_CHANGE_POKER)
	local c1 = {}
	if game.needshulff then
		AddTimer(game.id, timerid.T_DEAL_CHANGE_POKER, game.gameconf.dealchangepokertime)
		casino.Shuffle(game.changecards)
		local pos = 1
		for k, v in pairs(game.gameplayer) do
			if v.changenum > 0 then
				local getcards = {}
				getcards, pos = casino.PopCards(game.changecards, v.changenum, pos)
				casino.AddCards(v.cards, getcards)
				local retcards = {}
				for i, j in pairs(getcards) do
					local c = MSG.pack("card", j.point,j.suit)
					table.insert(retcards, c)
				end
				SendTo(game, v.uid, cmd.SMSG_CHANGE_RETURN, game.needshulff, retcards)
			end
		end
		for k, v in pairs(game.players) do
			if not game.gameplayer[v.uid] then
				SendTo(game, v.uid, cmd.SMSG_CHANGE_RETURN, game.needshulff, c1)
			end
		end
	else
		AddTimer(game.id, timerid.T_DEAL_CHANGE_POKER, 1)
		for k, v in pairs(game.players) do
			SendTo(game, v.uid, cmd.SMSG_CHANGE_RETURN, game.needshulff, c1)
		end
	end
end

local function GetLastResult(game)
	local bankerlose = 0
	local banker = game.gameplayer[game.banker]
	for k, v in pairs(game.gameplayer) do
		if v.uid ~= game.banker and v.totaladd > 0 then
			bankerlose = math.floor(bankerlose + v.totaladd * game.gameconf.basebet)
		end
	end
	if game.forcequitplayer then
		for k, v in pairs(game.forcequitplayer) do
			banker.winmoney = banker.winmoney - v
			local result = MSG.pack("bf_result", k, 0, v, 0, {})
			table.insert(game.lastresult, result)
			game.tablelog.log = game.tablelog.log .. "\n UID:"..k.." win:0 "..v
		end
	end
	local bankermoney = game.bankermoney + banker.winmoney
	for k, v in pairs(game.gameplayer) do
		if v.totaladd > 0 and v.uid ~= game.banker then
			if bankermoney >= bankerlose then
				v.winmoney = math.floor(v.totaladd * game.gameconf.basebet)
			else
				v.winmoney = math.floor((v.totaladd * game.gameconf.basebet / bankerlose) * bankermoney)
			end
			banker.winmoney = banker.winmoney - v.winmoney
			AddMoney(game, v.uid, v.winmoney)
		end
		game.tablelog.log = game.tablelog.log .. "\n UID:"..v.uid.." win:"..v.totaladd.." "..v.winmoney
		if v.uid ~= game.banker then
			pcall(skynet.send, game.players[v.uid].address, "lua", cmd.EVENT_PLAY_ONE_MATCH, v.totaladd, v.choicecards, v.pokertype)
			local cards = {}
			for i, j in pairs(v.choicecards) do
			local card = MSG.pack("card", j.point, j.suit)
				table.insert(cards, card)
			end
			local result = MSG.pack("bf_result", v.uid, v.totaladd, v.winmoney, v.pokertype, cards)
			table.insert(game.lastresult, result)
		end
	end
	AddMoney(game, banker.uid, banker.winmoney)
	pcall(skynet.send, game.players[banker.uid].address, "lua", cmd.EVENT_PLAY_ONE_MATCH, banker.totaladd, banker.choicecards, banker.pokertype)
	game.bankermoney = game.bankermoney + banker.winmoney
	if game.bankermoney < (game.gameconf.basebet * 30) then
		game.needgrabbanker = true
		game.grabresontype = 1
		game.playcount = 0
	end
	game.tablelog.log = game.tablelog.log .. "\n UID:"..banker.uid.." win:"..banker.totaladd.." "..banker.winmoney
	game.havegetresult = true
	game.tablelog.log = game.tablelog.log .. "\n"
	local cards = {}
	for i, j in pairs(banker.choicecards) do
		local card = MSG.pack("card", j.point, j.suit)
		table.insert(cards, card)
	end
	local result = MSG.pack("bf_result", banker.uid, banker.totaladd, banker.winmoney, banker.pokertype, cards)
	table.insert(game.lastresult, result)
end

local function GameOver(game) 
	Broadcast(game, nil, cmd.SMSG_GAME_OVER)
	skynet.send("mysql", "lua", cmd.SQL_TABLE_LOG, game.tablelog)
end

local function GetPlayerNumInGame(game)
	local num = 0
	local uids = {}
	if game.gameplayer then
		for k, v in pairs(game.gameplayer) do
			table.insert(uids, v.uid)
			num = num + 1
		end
	end
	return num, uids
end

local function GameOverAhead(game)  
	if not game.havegetresult then
		local totalmoney = 0
		for k, v in pairs(game.forcequitplayer) do
			totalmoney = totalmoney + v
			local result = MSG.pack("bf_result", k, 0, v, 0, {})
			table.insert(game.lastresult, result)
			game.tablelog.log = game.tablelog.log .. "\n UID:"..k.." win:0 "..v
		end
		if game.gameconf.fee ~= 0 then
			local backmoney = math.floor(game.gameconf.fee * totalmoney + 0.5)
			totalmoney = totalmoney - backmoney
			local backconf = {money = backmoney, gametype = game.gameconf.gametype,
				roomtype = game.gameconf.roomtype, moneytype = game.gameconf.basebet}
			skynet.send("mysql", "lua", cmd.SQL_BACK_MONEY, backconf)
		end
		local playernum, _ = GetPlayerNumInGame(game)
		local oneadd = totalmoney / playernum
		for k, v in pairs(game.gameplayer) do
			if v.winmoney < 0 then
				AddMoney(game, v.uid, oneadd - v.winmoney)
			else
				AddMoney(game, v.uid, oneadd)
			end
			v.winmoney = oneadd
			local cards = {}
			for i, j in pairs(v.choicecards) do
				local card = MSG.pack("card", j.point, j.suit)
				table.insert(cards, card)
			end
			local result = MSG.pack("bf_result", v.uid, v.totaladd, v.winmoney, v.pokertype, cards)
			table.insert(game.lastresult, result)
			game.tablelog.log = game.tablelog.log .. "\n UID:"..v.uid.." win:"..v.totaladd.." "..v.winmoney
		end
	end
	game.havegetresult = true
	game.tablelog.log = game.tablelog.log .. "\n"
--	Broadcast(game, nil, cmd.SMSG_BF_SHOW_RESULT, game.lastresult)
	ChangeState(game, states.SHOW_RESULT)
	AddTimer(game.id, timerid.T_WAIT_SHOW_RESULT, game.gameconf.waitshowresulttime)
end 

local function ForceStand(game, uid, selfmoney) 
	local needlosemoney = 0
	local num, _  = GetPlayerNumInGame(game)
	if game.seater[uid] then
		if game.gameplayer[uid] and IsGameStart(game) then
			local plr = game.gameplayer[uid]
	--		local num, _  = GetPlayerNumInGame(game)
			if plr.winmoney ~= 0 then
				needlosemoney = plr.winmoney
			else
				local loseone = game.gameconf.basebet * 3
				if uid == game.banker then
					if selfmoney < (num - 1) * loseone then
						loseone = selfmoney / (num - 1)
					end
					needlosemoney = (num - 1) * loseone
					for k, v in pairs(game.gameplayer) do
						if v.uid ~= game.banker then
							v.winmoney = loseone
							AddMoney(game, v.uid, v.winmoney + v.betmoney)
						end
					end
				else
					game.gameplayer[game.banker].winmoney = loseone
					needlosemoney = loseone
				end
			end
			Broadcast(game, nil, cmd.SMSG_FORCE_QUIT_GAME, uid, -needlosemoney)
			game.forcequitplayer[uid] = -needlosemoney
			game.tablelog.log = game.tablelog.log.."\n UID:"..uid.." escape"
			game.gameplayer[uid] = nil 
			if num == 1 or uid == game.banker then
		--	if GetPlayerNumInGame(game) == 1 or uid == game.banker then
				GameOverAhead(game)
				game.banker = 0
				game.playcount = 0
				game.grabresontype = 0
				game.needgrabbanker = true
			end
		end
		game.seater[uid] = nil
		game.gameplayer[uid] = nil 
		game.sitnum = game.sitnum - 1
		if uid == game.banker or game.sitnum < 2 then
			game.banker = 0
			game.playcount = 0
			game.grabresontype = 0
			game.needgrabbanker = true
		end
	end
	skynet.ret(skynet.pack(needlosemoney, game.tablelog.cardsid))
end

local function ForceQuit(game, uid, selfmoney)  
	PlayerTryStand(game, uid) 
	game.players[uid] = nil
end

local function ResertGame(game)  
	for k, v in pairs(game.players) do
		if game.seater[v.uid] and game.seater[v.uid].timeouttimes >= 2 then
			pcall(skynet.send, v.address, "lua", cmd.EVENT_KICK_FOR_GAME_OVER, true)
		else
			pcall(skynet.send, v.address, "lua", cmd.EVENT_KICK_FOR_GAME_OVER, false)
		end
	end
	RemoveTimer(game.id, nil)
	game.gameconf.comparepokertime = 0
	game.pos = 1
	game.gameplayer = {}
	game.lastresult	= {}
	game.forcequitplayer = {}
	game.havegetresult = false 
	game.bankermoney = 0
	game.starttime = 0
	game.topupling = 1
	if game.playcount >= 3 then
		game.playcount = 0
		game.needgrabbanker = true
		game.grabresontype = 3
	end
	if game.needgrabbanker then
		game.banker = 0
	end
	game.tablelog = {cardsid = nil, count = 0, playersid = nil, log = "start"}
	UpdateGameconf(game)
end


local function TakeFee(game) 
	if game.gameconf.ticket ~= 0 then
		local backmoney = 0
		local playerfee = math.floor(game.gameconf.ticket * game.gameconf.basebet + 0.5)
		local bankerfee = math.floor(game.gameconf.bankerticket * game.gameconf.basebet + 0.5)
		local fee = 0
		local uids = {}
		for k, v in pairs(game.gameplayer) do
			table.insert(uids, k)
			if k == game.banker then
				fee = bankerfee
			else
				fee = playerfee
			end
		local backconf = {money = fee, gametype = game.gameconf.gametype,
				roomtype = game.gameconf.roomtype, moneytype = game.gameconf.basebet}
			pcall(skynet.send, game.players[v.uid].address, "lua", cmd.EVENT_TAKE_FEE, fee, backconf)
			backmoney = backmoney + fee
		end
		Broadcast(game, nil, cmd.SMSG_TAKE_FEE, uids, playerfee, bankerfee)
--		local backconf = {money = backmoney, gametype = game.gameconf.gametype,
--				roomtype = game.gameconf.roomtype, moneytype = game.gameconf.basebet}
		game.bankermoney = game.bankermoney - fee
--		skynet.send("mysql", "lua", cmd.SQL_BACK_MONEY, backconf)
	end
end

local function Shuffle(game)
	casino.Shuffle(game.poker)
	game.pos = 1
end

local function DealPoker(game) 
	local test = false
--	local test = true
	if not test then
		Shuffle(game) --把一副扑克按照乱序排列
	else
		game.pos = 1
	end
	local cardnum = 5
--	local c1 = {{suit=2, point=14},{suit=1, point=10},{suit=3, point=10},{suit=1, point=12},{suit=2, point=11}}
--	local c2 = {{suit=1, point=10},{suit=2, point=12},{suit=2, point=13},{suit=2, point=10},{suit=1, point=12}}
	local flag = 1
	for k, v in pairs(game.gameplayer) do
		v.cards, game.pos = casino.PopCards(game.poker, cardnum, game.pos)
--		if flag == 1 then
--			casino.CopyCards(c1, v.cards)
--			flag = flag + 1
--		elseif flag == 2 then
--			casino.CopyCards(c2, v.cards)
--			flag = 1
--		end
		game.tablelog.log = game.tablelog.log .. "\n UID:" .. v.uid .. " Get cards:" .. casino.tostr(v.cards)
		local cards = {}
		for i, j in pairs(v.cards) do
			local card = MSG.pack("card", j.point, j.suit)
			table.insert(cards, card)
		end

--		for m, n in pairs(cards) do
--			local point, suit = MSG.upack("card", n)
--			print("....................point=", point, "suit=", suit, m)
--		end

		v.pokertype = casino.GetBFType(v.cards, v.choicecards)
		SendTo(game, k, cmd.SMSG_DEAL_POKER, cards, v.pokertype)
	end
	for k, v in pairs(game.players) do
		if not game.gameplayer[k] then
			SendTo(game, k, cmd.SMSG_DEAL_POKER, {}, 0)
		end
	end
end

local function NotifyBet(game)
	local num, _  = GetPlayerNumInGame(game)
	ChangeState(game, states.WAIT_BET)
	AddTimer(game.id, timerid.T_BET, game.gameconf.bettime)		
	game.starttime = os.time()
	TakeFee(game)
	Broadcast(game, nil, cmd.SMSG_NOTIFY_BET, game.gameconf.bettime)
	game.playcount = game.playcount + 1
--	local curup = math.ceil(game.bankermoney / num * game.gameconf.basebet)
	local curup = math.floor(game.bankermoney / (num * game.gameconf.basebet))
--	local curup = math.ceil(game.bankermoney / (GetPlayerNumInGame(game)*game.gameconf.basebet))
	if curup >= types.upling[#types.upling] then
		game.topupling = types.upling[#types.upling]
	else
		for k, v in pairs(types.upling) do
			if curup < v then
				game.topupling = v
				return
			end
		end
	end
end

local function CheckStartGame(game)
	if game.sitnum >= 2 then
		if not game.needgrabbanker then -- 等待抢庄阶段已经完成，进入决定庄家阶段(即指针动画)或下注阶段
			ChangeState(game, states.WAIT_BET)
			if game.bankersourcetype == 1 or game.bankersourcetype == 2 then --出现多人抢或多人不抢会有转动指针动画过程
				AddTimer(game.id, timerid.T_WAIT_BET, game.gameconf.waitbettime)
			else -- 直接进入下注阶段，不出现转动指针动画
				NotifyBet(game)
			end
			game.bankersourcetype = 0
		else --进入抢庄阶段，玩家选择抢或不抢
			ChangeState(game, states.GRAB_THE_BANKER)
			AddTimer(game.id, timerid.T_GRAB_BANKER, game.gameconf.grabbankertime)		
			for k, v in pairs(game.gameplayer) do
				pcall(skynet.send, game.players[v.uid].address, "lua", cmd.EVENT_GET_MONEY)
			end
			Broadcast(game, nil, cmd.SMSG_GRAB_BANKER, game.gameconf.grabbankertime, game.grabresontype)
		end
	else
		RemoveTimer(game.id, nil)
		game.gameplayer = {}
		ChangeState(game, states.WAIT_PLAYER)
	end
end

local function PlayerTryStand(game, uid)  
	if game.gameplayer[uid] and IsGameStart(game) then
		return error.GAME_HAVE_STARTED 
	else
		if game.seater[uid] then
			game.seater[uid] = nil
			game.sitnum = game.sitnum - 1
			if uid == game.banker or game.sitnum < 2 then
				if uid == game.banker and game.sitnum >= 2 then
					game.grabresontype = 4
				else
					game.grabresontype = 0
				end
				game.banker = 0
				game.playcount = 0
				game.needgrabbanker = true
			end
		end
		game.gameplayer[uid] = nil
		return 0
	end
end

local function PlayerTryQuit(game, uid)
	if game.gameplayer[uid] and IsGameStart(game) then
		return error.GAME_HAVE_STARTED
	else
		if game.seater[uid] then
			game.seater[uid] = nil
			game.sitnum = game.sitnum - 1
			if uid == game.banker or game.sitnum < 2 then
				if uid == game.banker and game.sitnum >= 2 then
					game.grabresontype = 4
				else
					game.grabresontype = 0
				end
				game.banker = 0
				game.playcount = 0
				game.needgrabbanker = true
			end
		end
		game.players[uid] = nil
		game.gameplayer[uid] = nil
		return 0
	end
end

local function ResumeGame(game, uid) 
	local users = {}
	local lefttime = 0
	if IsGameStart(game) then
		local user = {}
		for k, v in pairs(game.gameplayer) do
			local user = {uid = v.uid, state = game.curstate, pokertype = -1, cards = {}, grabsign = v.grabbanker, betmoney = v.betmoney}
			if v.havechoice then
				user.pokertype = v.pokertype
				for i, j in pairs(v.choicecards) do
					local card = MSG.pack("card", j.point, j.suit)
					table.insert(user.cards, card)
				end
			elseif uid == v.uid and #v.cards ~= 0 then
				for i, j in pairs(v.cards) do
					local card = MSG.pack("card", j.point, j.suit)
					table.insert(user.cards, card)
				end
			end
			local body = MSG.pack("bf_users_state", user.uid, user.state, user.pokertype, user.cards, user.grabsign, user.betmoney)
			table.insert(users, body)
		end
	end
	if game.curstate == states.WAIT_BET then
		lefttime = game.starttime + game.gameconf.bettime - os.time()
	elseif game.curstate == states.CHOICE_POKER_TYPE then
		lefttime = game.starttime + game.gameconf.choicepokertime - os.time()
	elseif game.curstate == states.SHOW_RESULT then
		lefttime = game.starttime + game.gameconf.showresulttime - os.time()
	end
	SendTo(game, uid, cmd.SMSG_BF_RESUME_GAME, users, lefttime, game.banker)
end

local function SomeOneChoicePoker(game, uid, ...)
	local body = {...}
	local player = game.gameplayer[uid]
	local errcode = 0
	if player ~= nil then
		local t, c = MSG.upack(cmd.CMSG_BF_POKER_TYPE, body[4])
		local cards = {}
		for k, v in pairs(c) do
			local point, suit = MSG.upack("card", unpack(v))
			local card = {point = point, suit = suit}
			table.insert(cards, card)
		end
		if #cards ~= 5 then
			errcode = error.CARDS_SIZE_ERROR
		elseif false == casino.HasCards(player.cards, cards) then
			errcode = error.NOT_THE_SAME_CARDS
		else
			if t == player.pokertype or t == 0 then
				player.pokertype = t
				casino.CopyCards(cards, player.choicecards)
				game.seater[uid].timeouttimes = 0
				if t >= types.PT_BULL_BULL then
					game.needgrabbanker = true
					game.grabresontype = 2
				end
			else
				errcode = error.CARDS_TYPE_ERROR
			end
		end
		if errcode == 0 then
			Broadcast(game, nil, cmd.SMSG_BF_SOME_ONE_CHOICE, uid, true, t, c)
			player.havechoice = true
			game.tablelog.log = game.tablelog.log .. "\n UID:"..uid.." Choice cards:"..casino.tostr(player.choicecards)
		else
			SendTo(game, uid, cmd.SMSG_BF_SOME_ONE_CHOICE, uid, false, errcode, {}) 
		end
	end
end

local function ShowResPlayersCPType(game)
	for k, v in pairs(game.gameplayer) do
		if not v.havechoice then
			local cards = {}
			for i, j in pairs(v.choicecards) do
				local card = MSG.pack("card", j.point, j.suit)
				table.insert(cards, card)
			end
--			v.pokertype = 0
			if v.pokertype >= types.PT_BULL_BULL then
				game.needgrabbanker = true
				game.grabresontype = 2
			end
			Broadcast(game, nil, cmd.SMSG_BF_SOME_ONE_CHOICE, v.uid, true, v.pokertype, cards)
			game.seater[v.uid].timeouttimes = game.seater[v.uid].timeouttimes + 1
			v.havechoice = true
		end
	end
end

local function IsAllPlayerChoiced(game)
	for k, v in pairs(game.gameplayer) do
		if not v.havechoice then
			return false
		end
	end
	return true
end

local function SomeOneGrab(game, uid, ...)
	local body = {...}
	local plr = game.gameplayer[uid]
	if plr and plr.grabbanker == 0 then
		plr.money = tonumber(body[5])
		plr.grabbanker = tonumber(body[4])
		Broadcast(game, nil, cmd.SMSG_SOME_ONE_GRAB_BANKER, uid, plr.grabbanker)
	end
end

local function AllHaveGrabed(game)
	local players, uids = GetPlayerNumInGame(game)
--	local basemoney = players * game.gameconf.basebet * 8
	local basemoney = game.gameconf.basebet * 30
	for k, v in pairs(game.gameplayer) do
		if v.money ~= 0 and v.money < basemoney then
			v.grabbanker = 2
		end
		if v.grabbanker == 0 then
			return false
		end
	end
	return true
end

local function ForResPlayerGrab(game, uid, ...)
	local body = {...}
--	local plr and plr.gameplayer[uid]
	for k, v in pairs(game.gameplayer) do
		if v.grabbanker == 0 or v.grabbanker == 2 then
	--	if v.grabbanker == 0 then
			Broadcast(game, nil, cmd.SMSG_SOME_ONE_GRAB_BANKER, v.uid, 2)
		end
	end
end

local function NotifyTheGrab(game)
	local grab = {}
	local topmoneyid = 0
	local topmoney = 0
--	game.grabresontype = 0
	for k, v in pairs(game.gameplayer) do
		if v.grabbanker == 1 then
			table.insert(grab, v.uid)
		end
		if v.money >= topmoney then
			topmoney = v.money
			topmoneyid = v.uid
		end
	end

	if #grab ~= 0 then
		if #grab == 1 then
			game.banker = grab[1]
		else
			math.randomseed(os.time())
			local rand = math.random(1, #grab)
			game.banker = grab[rand]
			game.bankersourcetype = 2
		end
	else
		game.banker = topmoneyid
		game.bankersourcetype = 1
	end

	game.needgrabbanker = false
	game.grabresontype = 0
	game.playcount = 0
	game.bankermoney = game.gameplayer[game.banker].money
	Broadcast(game, nil, cmd.SMSG_NOTIFY_THE_BANKER, game.banker, game.bankersourcetype)
	for k, v in pairs(game.gameplayer) do
		v.grabbanker = 0
	end
	CheckStartGame(game)
end

local function IsAllHaveBet(game)
	for k, v in pairs(game.gameplayer) do
		if v.betmoney  == 0 and v.uid ~= game.banker then
			return false
		end
	end
	return true
end

local function BetForResPlayer(game)
	for k, v in pairs(game.gameplayer) do
		if v.betmoney == 0 and v.uid ~= game.banker then
			v.betmoney = game.gameconf.basebet
			Broadcast(game, nil, cmd.SMSG_SOME_ONE_BET, v.uid, v.betmoney, 0)
		end
	end
end

local function SomeOneBet(game, uid, ...)
	local body = {...}
	local plr = game.gameplayer[uid]
	local betmoney = body[4]
	if plr then
		if betmoney > game.topupling * game.gameconf.basebet then
			SendTo(game, uid, cmd.SMSG_SOME_ONE_BET, uid, 0, error.BET_MONEY_ERROR)
		else
			plr.betmoney = betmoney
			Broadcast(game, nil, cmd.SMSG_SOME_ONE_BET, uid, plr.betmoney, 0)
		end
	end
end

local function LoserGetResult(game, uid, ...)
	local body = {...}
	local playermoney = body[4]
	local player = game.gameplayer[uid]
	if player and player.winmoney == 0 and player.totaladd < 0 then
		local needlose = player.totaladd * game.gameconf.basebet
		if playermoney >= - needlose then
			player.winmoney = needlose
		else
			player.winmoney = - playermoney
		end
		game.gameplayer[game.banker].winmoney = game.gameplayer[game.banker].winmoney - player.winmoney
		skynet.ret(skynet.pack(- player.winmoney, game.tablelog.cardsid))
	end
end

local function CanGetLastResult(game)
	if game.bankermoney ~= 0 then
		for k, v in pairs(game.gameplayer) do
			if v.uid ~= game.banker and v.winmoney == 0 and v.totaladd < 0 then
				return false
			end
		end
		return true
	else
		return false
	end
end

command[states.WAIT_PLAYER] = function(game, mtype, uid, ...)
	if cmd.EVENT_SOME_ONE_SIT == mtype then
		if game.sitnum >= 2 and not server_close then
			AddTimer(game.id, timerid.T_WAIT_START, game.gameconf.waitstarttime)
			ChangeState(game, states.WAIT_START_GAME)
		end
	end
end

command[states.WAIT_START_GAME] = function(game, mtype, uid, ...)
	if game.gameconf.gametype == types.GAME_TYPE_BULLFIGHT then
		if timerid.T_WAIT_START == mtype then
			if AddPlayerToGame(game) >= 2 then
				Broadcast(game, nil, cmd.SMSG_BF_GAME_START, GetPlayerNumInGame(game))
				skynet.send("myredis", "lua", "record_game_num", game.gameconf.roomtype)
			end
			CheckStartGame(game)
		elseif cmd.CMSG_TRY_STAND == mtype or cmd.CMSG_TRY_QUIT == mtype then
			if game.sitnum < 2 then
				RemoveTimer(game.id, timerid.T_WAIT_START)
				ChangeState(game, states.WAIT_PLAYER)
			end
		end
	end
end

command[states.GRAB_THE_BANKER] = function(game, mtype, uid, ...)
	if timerid.T_GRAB_BANKER == mtype then
		ForResPlayerGrab(game)
		NotifyTheGrab(game)
	elseif cmd.EVENT_PLAYER_MONEY == mtype then
		local body = {...}
		if game.gameplayer[uid] then
			if body[4] == nil then
			end
			game.gameplayer[uid].money = body[4]
		end
--	elseif timerid.T_SHOW_BANKER == mtype then
--		CheckStartGame(game)
	elseif mtype == cmd.CMSG_SOME_ONE_GRAB then
		SomeOneGrab(game, uid, ...)
		if AllHaveGrabed(game) then
			ForResPlayerGrab(game)
			NotifyTheGrab(game)
		end
	end
end

command[states.WAIT_BET] = function(game, mtype, uid, ...)
	if timerid.T_BET == mtype then
		if not IsAllHaveBet(game) then
			BetForResPlayer(game)
		end
		ChangeState(game, states.DEAL_POKER)
		DealPoker(game)
		AddTimer(game.id, timerid.T_DEAL_POKER, game.gameconf.dealpokertime)
	elseif timerid.T_WAIT_BET == mtype then
		NotifyBet(game)
	elseif cmd.EVENT_SOMEONE_BET == mtype then
		SomeOneBet(game, uid, ...)
		if IsAllHaveBet(game) then
			ChangeState(game, states.DEAL_POKER)
			DealPoker(game) 
			AddTimer(game.id, timerid.T_DEAL_POKER, game.gameconf.dealpokertime)
		end
	end
end

command[states.DEAL_POKER] = function(game, mtype, uid, ...)
	if game.gameconf.gametype == types.GAME_TYPE_BULLFIGHT then
		if timerid.T_DEAL_POKER == mtype then
			NotifyPlayerChoicePoker(game) 
			ChangeState(game, states.CHOICE_POKER_TYPE)
			AddTimer(game.id, timerid.T_CHOICE_POKER, game.gameconf.choicepokertime)
			game.starttime = os.time()
		end
	end
end

command[states.CHOICE_POKER_TYPE] = function(game, mtype, uid, ...)
	if timerid.T_CHOICE_POKER == mtype then
		ShowResPlayersCPType(game)
		GetCompareResult(game)
		AddTimer(game.id, timerid.T_WAIT_SHOW_RESULT, game.gameconf.waitshowresulttime)
		ChangeState(game, states.WAIT_SHOW_RESULT)
	elseif cmd.CMSG_BF_POKER_TYPE == mtype then
		SomeOneChoicePoker(game, uid, ...)
		if IsAllPlayerChoiced(game) then
			GetCompareResult(game)
			AddTimer(game.id, timerid.T_WAIT_SHOW_RESULT, game.gameconf.waitshowresulttime)
			RemoveTimer(game.id, timerid.T_CHOICE_POKER)
			ChangeState(game, states.WAIT_SHOW_RESULT)
		end
	end
end

command[states.WAIT_SHOW_RESULT] = function(game, mtype, uid, ...)
	if cmd.EVENT_LOSER_GET_RESULT == mtype then
		LoserGetResult(game, uid, ...)
		if CanGetLastResult(game) then
			GetLastResult(game)
		end
	elseif cmd.EVENT_BANKER_MONEY == mtype then
		local body = {...}
		game.bankermoney = body[4]
		if CanGetLastResult(game) then
			GetLastResult(game)
		end
	elseif timerid.T_WAIT_SHOW_RESULT == mtype then
		ChangeState(game, states.SHOW_RESULT)
		Broadcast(game, nil, cmd.SMSG_BF_SHOW_RESULT, game.lastresult)
		AddTimer(game.id, timerid.T_SHOW_RESULT, game.gameconf.showresulttime)
	end
end

command[states.SHOW_RESULT] = function(game, mtype, uid, ...)
	if timerid.T_SHOW_RESULT == mtype then
		GameOver(game) 
		ChangeState(game, states.WAIT_PLAYER)
		ResertGame(game) 
		if game.sitnum >= 2 and not server_close then
			ChangeState(game, states.WAIT_START_GAME)
			AddTimer(game.id, timerid.T_WAIT_START, game.gameconf.waitstarttime)
		elseif server_close then
			local close = true
			for k, v in pairs(all_games) do
				if IsGameStart(v) then
					close = false
					break
				end
			end
			if close then
				skynet.send("CPCenter", "lua", cmd.EVENT_SHUT_DOWN)
			end
		end	
	end
end

local function NeedUpdateGameconf(conf)
	local game = GetGame(conf.roomid)
	if not game then
		CreatGame(conf)
	end
	game.updateconf = conf
	if not IsGameStart(game) then
		UpdateGameconf(game)
	end
end

local function Enter(game, uid, address)
	if not game.players[uid] then
		game.players[uid] = {uid = uid, address = address}
	else
		game.players[uid].address = address
	end
	ResumeGame(game, uid)
end

local function Sit(game, uid)
	if game.seater == nil then
		game.seater = {}
	end
	if not game.seater[uid] then
		game.sitnum = game.sitnum + 1
	end
	game.seater[uid] = {uid = uid, timeouttimes = 0}
end

local function Pretreat(game, uid, address, mtype, body)
	if cmd.EVENT_SOME_ONE_ENTER == mtype then
		Enter(game, uid, address)
--	elseif cmd.EVENT_SOME_ONE_QUIT == mtype then
--		ForceQuit(game, uid, body[4])
	elseif cmd.EVENT_SOME_ONE_SIT == mtype then
		Sit(game, uid)
--	elseif cmd.EVENT_SOME_ONE_STAND == mtype then
--		ForceStand(game, uid, body[4]) 
	elseif cmd.CMSG_TRY_STAND == mtype then
		skynet.ret(skynet.pack(PlayerTryStand(game, uid)))
	elseif cmd.CMSG_TRY_QUIT == mtype then
		skynet.ret(skynet.pack(PlayerTryQuit(game, uid)))
	end
end

skynet.register_protocol{
	name = "relay",
	id = 20,
	pack = function(...) return ... end,
	unpack = function(...) return ... end
}

skynet.register_protocol{
	name = "game",
	id = 100,
	pack = function(...) return skynet.pack(...) end,
	unpack = function(...) return skynet.unpack(...) end,
	dispatch = function(session, address, ...)
		local body = {...}
		local gameid, uid, mtype = ... 
		local game = GetGame(gameid)
		Pretreat(game, uid, address, mtype, body)
		local f = command[game.curstate]
		if f then
			f(game, mtype, uid, ...)
		end
	end
}

skynet.start(function()
	skynet.dispatch("text", function(session, address, text)
		if text == "CLOSE" then
			print("close cpgame server")
		end
	end)
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local type, conf = body[1], body[2]
		if type == "SERVER_CLOSE" then
			server_close = true
			local close = true
			for k, v in pairs(all_games) do
				if IsGameStart(v) then
					close = false
					break
				end
			end
			if close then
				skynet.send("CPCenter", "lua", cmd.EVENT_SHUT_DOWN)
			end
		elseif type == "CREAT_GAME" then
			CreatGame(conf)
		elseif type == "UPDATE_GAME" then
			NeedUpdateGameconf(conf)
		end
	end)
	print("Start bfgame service")
end)

skynet.register(types.server_name["game"][11])


