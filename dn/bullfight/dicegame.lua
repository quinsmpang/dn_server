local skynet = require "skynet"
local cmd = require "cmd"
require "gameprotobuf"
local protobuf = protobuf
local error = require "errorcode"
local table = table
local string = string
local pairs = pairs
local print = print
local timer = require "timer"

--local print =  function(...) end
local GP = protobuf.proto.game.package
local server_close = false
local all_games = {}
local command = {}
local timers = {}

local states = {
	WAIT_PLAYER				= 1,
	WAIT_START_GAME			= 2,
	ROOL_THE_DICE			= 3,
	WAIT_BET				= 4,
	SHOW_RESULT				= 5
}

local timerid = {
	T_WAIT_START			= 1,
	T_ROOL_DICE				= 2,
	T_WAIT_BET				= 3,
	T_SHOW_RESULT			= 4
}

local upling = {
	[1] = 1,	-- small	
	[2] = 1,	-- big
	[3] = 24,	-- three same point 	
	[4] = 60,	-- get four point
	[5] = 30,
	[6] = 17,
	[7] = 12,
	[8] = 8,
	[9] = 7,
	[10] = 6,
	[11] = 6,
	[12] = 7,
	[13] = 8,
	[14] = 12,
	[15] = 17,
	[16] = 30,
	[17] = 60,		-- get seventeen point
	[18] = 150,		-- three one point
	[19] = 150,		-- three two point
	[20] = 150,
	[21] = 150,
	[22] = 150,
	[23] = 150,		-- three six point
	[24] = 1,		-- have one point
	[25] = 1,
	[26] = 1,
	[27] = 1,
	[28] = 1,
	[29] = 1		-- have six point
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

local function CreatGame(gameconf)
	local id = gameconf.roomid
	if not all_games[id] then
		all_games[id] = {
			id				= id, 
			seater			= {}, 
			players			= {},
			timers			= {},
			diceinfo		= {},
			totalbet		= {},
			curstate		= states.WAIT_PLAYER,
			updateconf		= nil,
			gameconf		= gameconf,
			tablelog		= {cardsid = nil, count = 0, playersid = nil, log = "start"}
		}
		all_games[id].gameconf.dealpokertime = 10
		all_games[id].gameconf.bettime = 10
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

local function SendTo(game, uid, msg, msgtype)
	if msgtype then
		msg = protobuf.pack(GP..".Packet type body",  msgtype, msg)
	end
	local player = game.players[uid]
	if player then
		skynet.send(player.address, "relay", msg)
	end
end

local function SendEvent(game, uid, event, ...)
	local player = game.players[uid]
	if player then
		skynet.send(player.address, "lua", event, ...)
	end
end

local function Broadcast(game, msg, msgtype, exceptid)
	if msgtype then
		msg = protobuf.pack(GP..".Packet type body",  msgtype, msg)
	end
	if game.players ~= nil then
		for k, v in pairs(game.players) do
			if exceptid then
				if exceptid ~= v.uid then
					skynet.send(v.address, "relay", msg)
				end
			else
				skynet.send(v.address, "relay", msg)
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
	if game.curstate == states.WAIT_BET then
		return true
	end
	return false
end

local function AddMoney(game, uid, money) 
	SendEvent(game, uid, cmd.EVENT_ADD_MONEY, money, game.tablelog.cardsid)
end

local function LoseMoney(game, uid, money) 
	SendEvent(game, uid, cmd.EVENT_LOSE_MONEY, money)
end

local function PlayerTryStand(game, uid)  
	if game.seater[uid] and #game.seater[uid].betinfo ~= 0 and IsGameStart(game) then
		return error.GAME_HAVE_STARTED 
	else
		game.seater[uid] = nil
		return 0
	end
end

local function PlayerTryQuit(game, uid)
	if game.seater[uid] and #game.seater[uid].betinfo ~= 0 and IsGameStart(game) then
		return error.GAME_HAVE_STARTED
	else
		game.seater[uid] = nil
		game.players[uid] = nil
		return 0
	end
end

local function ForceStand(game, uid, selfmoney) 
	local needlosemoney = 0
	game.seater[uid] = nil
	skynet.ret(skynet.pack(needlosemoney, game.tablelog.cardsid))
end

local function ForceQuit(game, uid, selfmoney)  
	ForceStand(game, uid, selfmoney) 
	game.players[uid] = nil
end

local function ResertGame(game)  
	for k, v in pairs(game.players) do
		if game.seater[v.uid] then
			game.seater[v.uid].betinfo = {}
			game.seater[v.uid].winmoney = 0
			if game.seater[v.uid].timeouttimes >= 2 then
				skynet.send(v.address, "lua", cmd.EVENT_KICK_FOR_GAME_OVER, true)
			end
		else
			skynet.send(v.address, "lua", cmd.EVENT_KICK_FOR_GAME_OVER, false)
		end
	end
	RemoveTimer(game.id, nil)
	game.starttime = 0
	game.diceinfo = {}
	game.totalbet = {}
	game.tablelog = {cardsid = nil, count = 0, playersid = nil, log = "start"}
	UpdateGameconf(game)
end

local function RoolTheDice(game) 
	for i = 1, 3 do
		local rand = math.random(1, 6)
		table.insert(game.diceinfo, rand)
	end
	local packet = protobuf.pack(GP..".SMSG_ROOL_THE_DICE")
	Broadcast(game, packet, cmd.SMSG_ROOL_THE_DICE)
	game.tablelog.log = game.tablelog.log .. "\n dice:" .. game.diceinfo[1] .. " " .. game.diceinfo[2] .. " " ..game.diceinfo[3]
end

local function CheckStartGame(game)
	if game.sitnum >= 1 then
		ChangeState(game, states.ROOL_THE_DICE)
		RoolTheDice(game) 
		AddTimer(game.id, timerid.T_ROOL_DICE, game.gameconf.dealpokertime)		
	else
		ChangeState(game, states.WAIT_PLAYER)
	end
end

local function ResumeGame(game, uid) 
	local betinfo = {}
	local lefttime = 0
	if game.curstate == states.WAIT_BET then
		for k, v in pairs(game.totalbet) do
			local bet = protobuf.pack(GP..".bet bettype money", k, v)
			table.insert(betinfo, bet)
		end
		lefttime = game.starttime + game.gameconf.bettime - os.time()
	else if game.curstate == states.SHOW_RESULT then
			lefttime = game.starttime + game.gameconf.showresulttime - os.time()
		end
	end
	local body = protobuf.pack(GP..".SMSG_RESUME_DICE_GAME state betinfo lefttime", game.curstate, betinfo, lefttime)
	SendTo(game, uid, body, cmd.SMSG_RESUME_DICE_GAME)
end

local function GetSitNum(game)
	local num = 0
	for k, v in pairs(game.seater) do
		num = num + 1
	end
	return num
end

local function StartBet(game)
	ChangeState(game, states.WAIT_BET)
	AddTimer(game.id, timerid.T_WAIT_BET, game.gameconf.bettime)
	game.starttime = os.time()
	local body = protobuf.pack(GP..".SMSG_START_BET")
	Broadcast(game, body, cmd.SMSG_START_BET)
end

local function GetWinType(game)
	local wintype = {}
	local totalpoint = game.diceinfo[1] + game.diceinfo[2] + game.diceinfo[3]
	wintype[totalpoint] = upling[totalpoint]
	if totalpoint <= 9 then
		wintype[1] = upling[1]
	else
		dintype[2] = upling[2]
	end
	if game.diceinfo[1] == game.diceinfo[2] and game.diceinfo[2] == fame.diceinfo[3] then
		wintype[3] = upling[3]
		local point = game.diceinfo[1]
		wintype[17 + point] = upling[17 + point]
	end
	for k, v in pairs(game.diceinfo) do
		if wintype[23 + v] then
			wintype[23 + v] = wintype[23 + v] + 1
		else
			wintype[23 + v] = upling[23 + v]
		end
	end
end

local function ShowResult(game)
	local wintype = GetWinType(game)
	local result = {}
	for k, v in pairs(game.seater) do
		local winmoney = 0
		local addmoney = 0
		if #v.betinfo ~= 0 then
			local wininfo = {}
			for i, j in pairs(v.betinfo) do
				if wintype[i] then
					local win = wintype[i] * j
					winmoney = winmoney + win
					addmoney = win + j
					local body = protobuf.pack(GP..".dice_win_type type money", i, win)
					table.insert(wininfo, body)
				else
					winmoney = winmoney - j
				end
			end
			if addmoney > 0 then
				AddMoney(game, k, addmoney)
			end
			local body = protobuf.pack(GP..".dice_player_win uid wininfo totalwin", k, wininfo, winmoney)
			table.insert(result, body)
		end
	end			
	local body = protobuf.pack(GP..".SMSG_SHOW_DICE_RESULT dice_results", result)
	Broadcast(game, body, cmd.SMSG_SHOW_DICE_RESULT)
end

local function SomeOneBet(game, uid, ...)
	local msg = {...}
	local bettype = msg[4]
	local betmoney = msg[5]
	local seat = game.seater[uid]
	if seat then
		if not seat.betinfo[bettype] then
			seat.betinfo[bettype] = betmoney
		else
			seat.betinfo[bettype] = seat.betinfor[bettype] + betmoney
		end
		local body = protobuf.pack(GP..".SMSG_SOMEONE_BET uid bettype money", uid, bettype, betmoney)
		Broadcast(game, body, cmd.SMSG_SOMEONE_BET)
		skynet.ret(skyent.pack(true))
	else
		skynet.ret(skyent.pack(false))
	end
end

command[states.WAIT_PLAYER] = function(game, mtype, uid, ...)
	if cmd.EVENT_SOME_ONE_SIT == mtype then
		if not server_close then
			AddTimer(game.id, timerid.T_WAIT_START, game.gameconf.waitstarttime)
			ChangeState(game, states.WAIT_START_GAME)
		end
	end
end

command[states.WAIT_START_GAME] = function(game, mtype, uid, ...)
	if timerid.T_WAIT_START == mtype then
		CheckStartGame(game)
	end
end

command[states.ROOL_THE_DICE] = function(game, mtype, uid, ...)
	if timerid.T_ROOL_DICE == mtype then
		StartBet(game)
	end
end

command[states.WAIT_BET] = function(game, mtype, uid, ...)
	if timerid.T_WAIT_BET == mtype then
		ShowResult(game)
	elseif cmd.EVENT_SOMEONE_BET == mtype then
		SomeOneBet(game, uid, ...)
	end
end

command[states.SHOW_RESULT] = function(game, mtype, uid, ...)
	if timerid.T_SHOW_RESULT == mtype then
		ResertGame(game) 
		ChangeState(game, states.WAIT_PLAYER)
		if GetSitNum(game) >0 and not server_close then
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
	if game.players[uid] then
		if not game.seater then
			game.seater = {}
		end
		game.seater[uid] = {uid = uid, timeouttimes = 0, betinfo = {}, winmoney = 0}
	end
end

local function Pretreat(game, uid, address, mtype, body)
	if cmd.EVENT_SOME_ONE_ENTER == mtype then
		Enter(game, uid, address)
	elseif cmd.EVENT_SOME_ONE_QUIT == mtype then
		ForceQuit(game, uid, body[4])
	elseif cmd.EVENT_SOME_ONE_SIT == mtype then
		Sit(game, uid)
	elseif cmd.EVENT_SOME_ONE_STAND == mtype then
		ForceStand(game, uid, body[4]) 
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
		print("game recv message ", mtype, uid, gameid)
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
	print("Start dicegame service")
end)

skynet.register("DiceGame")

