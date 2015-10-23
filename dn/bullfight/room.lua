local cmd = require "cmd"
local error = require "errorcode"
local skynet = require "skynet" 
local serverconf = require "serverconf"
local MSG = require "gamepacket"
local types = require "types"
local unpack = unpack 
local ipairs = ipairs 
local pairs = pairs 
local assert = assert 

local command = {} 
local rooms = {}  
local players = {}
local retroom = {refreshtime = 0}
local fastroom = {}
local fastbasebet = {}
local game_service = {}

local timer = require"timer"
local trace_cache = {}
local trace_stat = {}
local tracetimer = timer.new()

skynet.trace_callback(function(handle, ti)
    local cmd = trace_cache[handle]
    if cmd then
	    local t = trace_stat[cmd]
        t.count = t.count + 1
        if ti > t.max then
            t.max = ti
        end
        t.tt = t.tt + ti
    end
    trace_cache[handle] = nil
end)

local function trace_start(cmd)
    trace_cache[skynet.trace()] = cmd
    if trace_stat[cmd] == nil then
        trace_stat[cmd] = { count = 0, max = 0, tt = 0 }
    end
end

local function WriteTraceLog()
	local str = "Room trace:\n"
	for k, v in pairs(trace_stat) do
		if v.count ~= 0 then
			str = str .. "cmd:"..k.."	count:"..v.count .. "		max:"..v.max.."		total:" .. v.tt .. "\n"
		end
	end
	skynet.error(str)
end

local function TraceCB()
	WriteTraceLog()
	tracetimer:start(6000, TraceCB)
end
local function SendTo(roomid, uid, msg)
	local room = rooms[roomid]
	if room and room.users and room.users[uid] then
--		skynet.send(room.users[uid].address, "relay", msg)
		pcall(skynet.send, room.users[uid].address, "relay", msg)
	end
end

local function RoomBroadcast(roomid, packet, exceptid)
	local room = rooms[roomid]
	if room then
		for k, v in pairs(room.users) do
			if k ~= exceptid then
				pcall(skynet.send, v.address, "relay", packet)
			end
		end
	end
end

local function RoomBroadcastEvent(roomid, exceptid, event, suid, ...)
	local room = rooms[roomid]
	if room then
		for k, v in pairs(room.users) do
			if k ~= exceptid then
				pcall(skynet.send, v.address, "lua", event, suid, ...)
			end
		end
	end
end

local function UpdateRoom(roomconf)
	local roomid = roomconf.roomid
	local room = rooms[roomid]
	if roomconf.roomtype ~= room.roomconf.roomtype or roomconf.basebet ~= room.roomconf.basebet
		or roomconf.minmoney ~= room.roomconf.minmoney or roomconf.ticket ~= room.roomconf.ticket
		or roomconf.fee ~= room.roomconf.fee or roomconf.state ~= room.roomconf.state
		or roomconf.choicepokertime ~= room.roomconf.choicepokertime 
		or roomconf.maxmoney ~= room.roomconf.maxmoney then
		room.roomconf = roomconf
		if types.server_name["game"][roomconf.gametype] then
--			skynet.send(types.server_name["game"][roomconf.gametype], "lua", "UPDATE_GAME", roomconf)
			pcall(skynet.send, types.server_name["game"][roomconf.gametype], "lua", "UPDATE_GAME", roomconf)
		end
	end
end

local function CreatRoom(roomconf)
	local roomid = roomconf.roomid
	if not rooms[roomid] then
		rooms[roomid] = {
			roomid = roomid,
			cursitn = 0,
			curusern = 0,
			seats = {},
			users = {},
			roomconf = roomconf
		}
		for i = 0, roomconf.seatnum - 1 do
			rooms[roomid].seats[i] = {seatid = i, uid = nil}
		end
		pcall(skynet.send, types.server_name["game"][roomconf.gametype], "lua", "CREAT_GAME", roomconf)
	else
		UpdateRoom(roomconf)
	end
end

local function InitRoom()
	local result = skynet.call("mysql", "lua",cmd.SQL_GET_ROOMCONF)
	if result and #result > 0 then
		fastroom = {}
		fastbasebet = {}
		for k, v in pairs(result) do
			local roomconf = {
				roomid		= tonumber(v[1]),
				roomtype	= tonumber(v[2]),
				seatnum		= tonumber(v[3]),
				maxuser		= tonumber(v[4]),
				basebet		= tonumber(v[5]),
				minmoney	= tonumber(v[6]),
				maxmoney	= tonumber(v[7]),
				ticket		= tonumber(v[8]),
				fee			= tonumber(v[9]),
				gametype	= tonumber(v[11]),
				state		= tonumber(v[12]),
				bankerticket = tonumber(v[13]),
				bankerresontime		= 1,
				waitstarttime		= 2,
				dealpokertime		= 1,
				changepokertime		= 15,
--				dealchangepokertime = 2,
				choicepokertime		= tonumber(v[10]),
			--	choicepokertime		= 10,
				comparepokertime	= 0,
				waitshowresulttime	= 1,
				showresulttime		= 7,
				grabbankertime		= 7,
				bettime				= 8,
				waitbettime			= 6,
			}
			CreatRoom(roomconf)
			if roomconf.state == 0 then
				if not fastroom[roomconf.gametype] then
					fastroom[roomconf.gametype] = {}
					fastbasebet[roomconf.gametype] = {}
				end
				if not fastroom[roomconf.gametype][roomconf.roomtype] then
					fastroom[roomconf.gametype][roomconf.roomtype] = {}
					fastbasebet[roomconf.gametype][roomconf.roomtype] = {}
				end
				if not fastroom[roomconf.gametype][roomconf.roomtype][roomconf.basebet] then
					fastroom[roomconf.gametype][roomconf.roomtype][roomconf.basebet] = {}
				end
				table.insert(fastroom[roomconf.gametype][roomconf.roomtype][roomconf.basebet], roomconf.roomid)
				fastbasebet[roomconf.gametype][roomconf.roomtype][roomconf.basebet] = {minmoney = roomconf.minmoney, maxmoney = roomconf.maxmoney}
			end
		end
	else 
		print("select roomconf from DB error")
	end
end

local function FindRoom()
	for k, v in pairs(rooms) do
		if v.cursitn < v.roomconf.seatnum then
			return k
		end
	end
end

local function GetEmptySeat(roomid, IP)
	local room = rooms[roomid]
	if not serverconf.TEST_MODEL then
		for k, v in pairs(room.seats) do
			if v.IP and v.IP == IP and IP ~= serverconf.test_IP1 and IP ~= serverconf.test_IP2 then
				return nil
			end
		end
	end
	if room then
		for k, v in pairs(room.seats) do
			if not v.uid then
				return k
			end
		end
	end
	return nil
end

local function GetSuitableBasebet_1(gametype, roomtype, money)
	local basebet = 0
	local in_nosit = false
	local rtype = roomtype
	for i, j in pairs(fastbasebet[gametype]) do
		if roomtype == 0 or roomtype >= i then
			for k, v in pairs(j) do
				if money >= v.minmoney and (money < v.maxmoney or v.maxmoney ~= 0) then
					rtype = i
					if (k == serverconf.basebet[1] and money <= serverconf.changeroom[1]) or
						(k == serverconf.basebet[2] and money > serverconf.changeroom[1] and money <= serverconf.changeroom[2]) or
						(k == serverconf.basebet[3] and money > serverconf.changeroom[2] and money <= serverconf.changeroom[3]) or
						(k == serverconf.basebet[4] and money > serverconf.changeroom[3] and money <= serverconf.changeroom[4]) or
						(k == serverconf.basebet[5] and money > serverconf.changeroom[4] and money <= serverconf.changeroom[5]) or
						(k == serverconf.basebet[6] and money > serverconf.changeroom[5] and money <= serverconf.changeroom[6]) or
						(k == serverconf.basebet[7] and money > serverconf.changeroom[6] and money <= serverconf.changeroom[7]) or
						(k == serverconf.basebet[8] and money > serverconf.changeroom[7]) then
						basebet = k
						break
					end
					basebet = k
				end
			end
		end
	end
	return basebet, rtype, in_nosit
end

--local function GetSuitableBasebet(gametype, roomtype, money)
--	local basebet = 0
--	local in_nosit = false
--	local rtype = roomtype
--	for i, j in pairs(fastbasebet[gametype]) do
----		if roomtype == 0 or roomtype <= i then
--		if roomtype == 0 or roomtype >= i then
--			for k, v in pairs(j) do
--				if money >= v.minmoney and (money < v.maxmoney or v.maxmoney ~= 0) and basebet < k then
--			--	if money >= v.minmoney and (money < v.maxmoney or v.maxmoney == 0) and basebet == 0 then
--					basebet = k
--					rtype = i
--				end
--					if roomtype ~= 1 and money < v.minmoney and basebet ~= 0 then
--						basebet = k
--						rtype = i
--						in_nosit = true
--					end
--			end
--		end
--	end
--	return basebet, rtype, in_nosit
--end

local function FastEnterRoom(enterconf, uplose, sumlose)
	local getroom = nil
	local getseatid = nil
	local isprotect = false
	local basebet = 0
	local in_nosit = false
	local roomtype = enterconf.roomtype
	local gametype = enterconf.gametype
	print("fast enter", enterconf.roomid, enterconf.basebet, gametype, roomtype, enterconf.money, enterconf.protectmoney == nil, basebet, fastroom[gametype] == nil, fastroom[gametype][roomtype] == nil)

	if sumlose <= serverconf.uplosemoney[0] then
		return error.OVER_SUMLOSE_LIMIT	
	end
	if enterconf.roomid then -- 换房进入此支线
		local room = rooms[enterconf.roomid]
		if room then
			basebet = room.roomconf.basebet
			gametype = room.roomconf.gametype
			roomtype = room.roomconf.roomtype
--			if enterconf.money < room.roomconf.minmoney then
--				return error.HAVE_NO_ENOUGH_MONEY
--				basebet = 0
--			elseif enterconf.money > room.roomconf.maxmoney then
				if enterconf.money < serverconf.changeroom[2] then --钱的界限是由策划规定的,数值需与客户端一致
					roomtype = 1
				elseif enterconf.money >= serverconf.changeroom[2] and enterconf.money < serverconf.changeroom[4] then
					roomtype = 2
				else 
					roomtype = 3
				end
				basebet = 0
--			end
		else
			return error.FAST_ENTER_FAILED
		end
	elseif not gametype or not roomtype then
		return error.FAST_ENTER_FAILED
	else
		enterconf.roomid = 0
		if enterconf.basebet then
			local maxmoney = fastbasebet[gametype][roomtype][enterconf.basebet].maxmoney
			if minmoney and minmoney <= enterconf.money and maxmoney > enterconf.money then
				basebet = enterconf.basebet
			else
				basebet = 0
			end
		end
	end

	if basebet == 0 then
--		basebet, roomtype, in_nosit = GetSuitableBasebet(gametype, roomtype, enterconf.money)
		basebet, roomtype, in_nosit = GetSuitableBasebet_1(gametype, roomtype, enterconf.money)
	end

	if basebet == 0 then
--		if enterconf.protectmoney ~= 0 then
--			basebet, roomtype, in_nosit = GetSuitableBasebet(gametype, roomtype, enterconf.money + enterconf.protectmoney)
			basebet, roomtype, in_nosit = GetSuitableBasebet_1(gametype, roomtype, enterconf.money + enterconf.protectmoney)
--		end
--		if basebet == 0 then
--			return error.HAVE_NO_ENOUGH_MONEY
	--	end
--		if enterconf.money > roomconf.maxmoney then
--			return error.HAVE_TOO_MANY_MONEY
--		end
--		else
			isprotect = true
--		end
	end

	if fastroom[gametype] and fastroom[gametype][roomtype] and fastroom[gametype][roomtype][basebet] then
--		for m, n in pairs(fastroom[gametype][roomtype]) do
--			for k, v in pairs(fastroom[gametype][roomtype][m]) do
			for k, v in pairs(fastroom[gametype][roomtype][basebet]) do
				if not uplose[enterconf.uid] then
					uplose[enterconf.uid] = {}
				end
				if not uplose[enterconf.uid][v] then
					uplose[enterconf.uid][v]= {}
					uplose[enterconf.uid][v].lose = 0
				end
				local room = rooms[v]
				if room and v ~= enterconf.roomid and room.cursitn < room.roomconf.seatnum and uplose[enterconf.uid][v].lose > serverconf.uplosemoney[roomtype] then
					local seatid = nil
					if not getroom or getroom.cursitn < room.cursitn then
						seatid = GetEmptySeat(room.roomid, enterconf.IP)
						if seatid then
							getroom = room
							getseatid = seatid
							if room.cursitn >= room.roomconf.seatnum - 5 then
								break
							end
						end
					end
				end
			end
--		end
	end

	if getroom then
		local users = getroom.users
		local seat = getroom.seats[getseatid]
		if not users[enterconf.uid] then
			users[enterconf.uid] = {address = enterconf.address,  uid = enterconf.uid, seatid = getseatid, info = enterconf.info}
			getroom.curusern = getroom.curusern + 1
			getroom.cursitn = getroom.cursitn + 1
			seat.uid = enterconf.uid
		else
			users[enterconf.uid].address = enterconf.address
			users[enterconf.uid].info = enterconf.info
		end
		return 0, getroom.roomconf, getseatid, isprotect, in_nosit
	else 
		return error.FAST_ENTER_FAILED
	end
end

local function BankerEnter(enterconf)
end

local function CheckEnter(address, uid, roomid, info, uplose, sumlose, roomtype_li)
	print("enter info",info)
	local room = rooms[roomid]
	if not room or room.roomconf.state ~= 0 then 
		return error.HAVE_NO_THIS_ROOM
	end
	local users = room.users
	local ret = 0
	if not users[uid] then
		if room.roomconf.maxuser <= room.curusern then
			ret = error.ROOM_IS_FULL
		else
			users[uid] = {address = address,  uid = uid, seatid = nil, info = info}
			room.curusern = room.curusern + 1
		end
	else
		users[uid].address = address
		users[uid].info = info
		ret = -1
	end
	if sumlose <= serverconf.uplosemoney[0] then
		ret = error.OVER_SUMLOSE_LIMIT
	end
	if uplose[uid][roomid] then
		if uplose[uid][roomid].lose <= serverconf.uplosemoney[roomtype_li] then
			ret = error.OVER_LOSE_LIMIT
		end
	end
			
	return ret, room.roomconf
end

local function CheckSit(uid, roomid, seatid, IP) 
	print(".................IP = ", IP)
	local room = rooms[roomid]
	local seat = room.seats[seatid]
	local user = room.users[uid]
	if not user then
		return error.PLAYER_NOT_IN_ROOM
	end
	if user.seatid then
		if seat.uid == uid then
			return 0, user.seatid
		else
			user.seatid = nil 
			return error.SEAT_HAVE_PLAYER
		end
	end
	if not seat then
		return error.HAVE_NO_THIS_SEAT
	end
--	if not serverconf.TEST_MODEL and IP ~= serverconf.test_IP1 and IP ~= serverconf.test_IP2 then
--		for k, v in pairs(room.seats) do
--			if v.IP and v.IP == IP then
--				return error.THE_SAME_IP_REFUSE
--			end
--		end
--	end
	if not seat.uid then
		seat.uid = uid
		seat.IP = IP
		room.cursitn = room.cursitn + 1
		user.seatid = seatid
		return 0, user.seatid
	else 
		return error.SEAT_HAVE_PLAYER
	end
end

local function CheckStand(uid, roomid, seatid) 
	local room = rooms[roomid]
	local user = room.users[uid]
	if not user then
		return error.PLAYER_NOT_IN_ROOM
	end
	if user.seatid then
		print("player stand", uid)
		if room.seats[seatid].uid then
			room.seats[seatid].uid = nil
			room.seats[seatid].IP = nil
			room.cursitn = room.cursitn - 1
			user.seatid = nil
		end
		return 0
	else
		return error.PLAYER_IS_NOT_SIT
	end
end

local function CheckQuitRoom(uid, roomid) 
	print("quit from",roomid)
	local room = rooms[roomid] 
	local user = room.users[uid]
	if user then
		if user.seatid then
			CheckStand(uid, roomid, user.seatid)
		end
	--	user = nil
		room.users[uid] = nil
		room.curusern = room.curusern - 1
		return 0
	else
		return error.PLAYER_NOT_IN_ROOM
	end
end
--[[
local function SetRetRoom()
	local getroom = {}
	retroom = {refreshtime = os.time()}
	for k, v in pairs(rooms) do
		local conf = v.roomconf
		if not getroom[conf.gametype] then
			getroom[conf.gametype] = {}
		end
		if not getroom[conf.gametype][conf.roomtype] then
			getroom[conf.gametype][conf.roomtype] = {}
		end
		if v.cursitn ~= 0 then
			local r = {sitn = v.cursitn, roomid = v.roomid}
			table.insert(getroom[conf.gametype][conf.roomtype], r)
		end
	end
	for k, v in pairs(getroom) do
		local typeroom = {}
		for i, j in pairs(v) do
			for m, n in pairs(j) do
				local room = MSG.pack("table", n, i)
				table.insert(typeroom, room)
			end
		end
		retroom[k] = MSG.pack(cmd.SMSG_TABLE_GETALL, tonumber(k), typeroom)
	end
end
]]

local function SetRetRoom()
	local getroom = {}
	retroom = {refreshtime = os.time()}
	for k, v in pairs(rooms) do
		if not getroom[v.roomconf.roomtype] then
			getroom[v.roomconf.roomtype] = {}
		end
		if v.cursitn ~= 0 then
			if not getroom[v.roomconf.roomtype][v.cursitn] then
				getroom[v.roomconf.roomtype][v.cursitn] = {}
			end
			table.insert(getroom[v.roomconf.roomtype][v.cursitn], v.roomid)
		end
	end
	for k, v in pairs(getroom) do
		local typeroom = {}
		for i, j in pairs(v) do
			for m, n in pairs(j) do
				local room = MSG.pack("table", n, i)
				table.insert(typeroom, room)
			end
		end
		retroom[k] = MSG.pack(cmd.SMSG_TABLE_GETALL, tonumber(k), typeroom)
--		local body = protobuf.pack(GP..".cmd.SMSG_TABLE_GETALL type tables", tonumber(k), typeroom)
--		retrrom[k] = protobuf.pack(GP..".Packet type body", cmd.SMSG_TABLE_GETALL, body)
	end
end

local function EnterSucc(uid, roomid, address, exceptuid)
	local room = rooms[roomid]
	if room and room.users then
		local seaters = {}
		for k, v in pairs(room.users) do
			if v.uid ~= uid then
				local body = MSG.pack(cmd.SMSG_SOMEONE_ENTER, v.uid, v.info)
				pcall(skynet.send, address, "relay", body)
			end
			if v.seatid and v.uid ~= exceptuid then
				local seater = MSG.pack("seater", v.uid, v.seatid)
				table.insert(seaters, seater)
			end
		end
		if #seaters ~= 0 then
			local body = MSG.pack(cmd.SMSG_SOMEONE_SIT, seaters)
			pcall(skynet.send, address, "relay", body)
		end
	end
end

command[cmd.CMSG_ENTER_ROOM] = function (param)
	local address, uid, roomid, info, uplose, sumlose, roomtype_li = unpack(param)
	local ret, roomconf = CheckEnter(address, uid, roomid, info, uplose, sumlose, roomtype_li)
	if ret == 0 or ret == -1 then
		RoomBroadcastEvent(roomid, 0, cmd.EVENT_SOME_ONE_ENTER, uid, roomid, info, ret)
		EnterSucc(uid, roomid, address)
	end
	skynet.ret(skynet.pack(ret, roomconf))
end

command[cmd.CMSG_FAST_ENTER] = function(param)
	local address, enterconf, uplose, sumlose = unpack(param)
	enterconf.address = address
	local ret, roomconf, seatid, isprotect, in_nosit = FastEnterRoom(enterconf, uplose, sumlose)
	if ret == 0 then
		RoomBroadcastEvent(roomconf.roomid, 0, cmd.EVENT_SOME_ONE_ENTER, enterconf.uid, roomconf.roomid, enterconf.info, ret)
		EnterSucc(enterconf.uid, roomconf.roomid, address, enterconf.uid)
	end
	skynet.ret(skynet.pack(ret, roomconf, seatid, isprotect, in_nosit))
end

command[cmd.EVENT_BANKER_ENTER] = function(param)
	local address, enterconf = unpack(param)
	enterconf.address = address
	local ret, roomconf, seatid = BankerEnter(enterconf)
	if ret == 0 then
		RoomBroadcastEvent(roomconf.roomid, 0, cmd.EVENT_SOME_ONE_ENTER, enterconf.uid, roomconf.roomid, enterconf.info, ret)
		EnterSucc(enterconf.uid, roomconf.roomid, address)
	end
	skynet.ret(skynet.pack(ret, roomconf, seatid))
end

command[cmd.CMSG_QUIT_ROOM] = function (param)
	local _, uid, roomid = unpack(param)
	local ret = CheckQuitRoom(uid, roomid)
	if ret == 0 then
		RoomBroadcastEvent(roomid, 0, cmd.EVENT_SOME_ONE_QUIT, uid, roomid)
	end
	skynet.ret(skynet.pack(ret))
end

command[cmd.CMSG_SIT] = function(param)
	local _, uid, roomid, seatid, money, IP = unpack(param)
	local ret, getseatid = CheckSit(uid, roomid, seatid, IP)
	if ret == 0 then
		RoomBroadcastEvent(roomid, 0, cmd.EVENT_SOME_ONE_SIT, uid, getseatid)
	end
	skynet.ret(skynet.pack(ret, getseatid))
end

command[cmd.CMSG_STAND] = function (param)
	local _, uid, roomid, seatid, notice = unpack(param)
	local ret = CheckStand(uid, roomid, seatid)
	if ret == 0 and notice then
		RoomBroadcastEvent(roomid, 0, cmd.EVENT_SOME_ONE_STAND, uid, roomid, seatid)
	end
	skynet.ret(skynet.pack(ret))
end

command[cmd.EVENT_GET_ROOMCONF] = function(param)
	local _, roomid = unpack(param)
	skynet.ret(skynet.pack(rooms[roomid].roomconf))
end

command[cmd.CMSG_TABLE_GETALL] = function(param)
	local address, roomtype = unpack(param)
	if not retroom[roomtype] then
		SetRetRoom()
	end
	if os.time() > retroom.refreshtime + 1 then
		SetRetRoom()
	end
	if retroom[roomtype] then
		skynet.ret(skynet.pack(retroom[roomtype]))
	else
		local typeroom = {}
		local body = MSG.pack(cmd.SMSG_TABLE_GETALL, roomtype, typeroom)
		skynet.ret(skynet.pack(body))
	end
--	if os.time() > retroom.refreshtime + 1 then
--		SetRetRoom()
--	end
end

command[cmd.ADMIN_UPDATE_ROOMCONF] = function(param)
	InitRoom()
end

command[cmd.EVENT_ROOM_BROADCAST] = function(param)
	local _, roomid, uid, packet = unpack(param)
	RoomBroadcast(roomid, packet, uid)
end

command[cmd.EVENT_ROOM_EVENT] = function(param)
	local _, roomid, exceptid, event, suid = unpack(param)
	RoomBroadcastEvent(roomid, exceptid, event, suid)
end

command[cmd.EVENT_SEND_TO] = function(param)
	local _, roomid, uid, msg = unpack(param)
	SendTo(roomid, uid, msg)
end

skynet.register_protocol{
	name = "relay",
	id = 20,
	pack = function(...) return ... end,
	unpack = function(...) return ... end,
	dispatch = function (session, address, msg, sz)
	end
}


skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		local t = {...}
		local mtype = t[1]
		t[1] = address
		local f = command[mtype]
		trace_start(mtype)
		if f then
			f(t)
		else
			print("[room] unknow command:", mtype)
		end
	end)
	print("Start bfroom service")
	InitRoom()
	tracetimer:start(6000, TraceCB)
end)

skynet.register(types.server_name["room"])

