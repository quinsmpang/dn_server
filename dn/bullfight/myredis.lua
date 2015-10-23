
require "mydebug"
local KEY = require "rediskey"
local skynet = require "skynet" 
local redis = require "redis"
local cmd = require "cmd"
local timer = require"timer"
local updatetimer = timer.new()
local flushtimer = timer.new()
local connect
local onetime = 0
local command = {}
local top_score = {}
local top_money = {}
local top_dayhonor = {}
local top_weekhonor = {}
local list_weekhonor = {}
local lastw_playerinfos = {}
local wishing_money = 0
local wishing_win_list = {}

local function Explain(str)
	local ret = {}
	for k, v in string.gmatch(str, "(%S*)%s*") do
		table.insert(ret, k)
	end
	table.remove(ret, #ret)
	return unpack(ret)
end

local function InitWishingWinList()
	wishing_win_list = {}
	local key = KEY.wishing_daywin..os.date("%Y%m%d")
	if connect:exists(key) then
		local str = string.format("%s desc by *->wtime get *->uid get *->money get *->wtime get *->name get *->sptype", key)
		local players = connect:SORT(Explain(str))
		if players then
			local player = {}
			local num = 1
			for k, v in pairs(players) do
				if num == 1 then
					player.uid = tonumber(v)
				elseif num == 2 then
					player.money = tonumber(v)
				elseif num == 3 then
					player.time = tonumber(v)
				elseif num == 4 then
					player.name = v
				elseif num == 5 then
					player.sptype = tonumber(v)
					table.insert(wishing_win_list, player)
					num = 0
				end
				num = num + 1
			end
		end
	end
end

local function UpdateWishingWell(upmoney)
	wishing_money = wishing_money + upmoney
	connect:SET(KEY.wishing_money, wishing_money)
end

local function InitWishingWell()
	if connect:exists(KEY.wishing_money) then
		wishing_money = connect:get(KEY.wishing_money)
	else
		wishing_money = 0
	end
end

local function BetWishingWell(uid, betmoney, roomid)
	UpdateWishingWell(betmoney)
	local key = KEY.wishing_bet..uid..os.time() 
	connect:HSET(key, "uid", uid)
	connect:HSET(key, "roomid", roomid)
	connect:HSET(key, "money", betmoney)
	connect:EXPIRE(key, 15*24*60*60)
	local daybetkey = KEY.wishing_daybet..os.date("%Y%m%d")
	connect:LPUSH(daybetkey, key)
end

local function WinWishingWell(uid, upling, sptype, roomid, name)
	local winmoney = wishing_money * upling
	UpdateWishingWell(-winmoney)
	local key = KEY.wishing_win..uid..os.time() 
	connect:HSET(key, "uid", uid)
	connect:HSET(key, "roomid", roomid)
	connect:HSET(key, "money", winmoney)
	connect:HSET(key, "sptype", sptype)
	connect:HSET(key, "name", name)
	connect:HSET(key, "wtime", os.time())
	connect:EXPIRE(key, 15*24*60*60)
	local daywinkey = KEY.wishing_daywin..os.date("%Y%m%d")
	connect:LPUSH(daywinkey, key)
	local winconf = {uid = uid, sptype = sptype, money = winmoney}
	table.insert(wishing_win_list, winconf)
	if #wishing_win_list > 50 then
		table.remove(wishing_win_list, 1)
	end
	return winmoney
end

local function UpdateInfo(player_info)
	local key = "UINFO_LI"..player_info.uid
	connect:HSET(key, "uid", player_info.uid)
	connect:HSET(key, "money", player_info.money)
	connect:HSET(key, "score", player_info.score)
	connect:HSET(key, "info", player_info.info)
	connect:HSET(key, "qq_vip", player_info.qq_vip)
	connect:HSET(key, "vip", player_info.vip)
	connect:HSET(key, "dayhonor", player_info.dayhonor)
	connect:HSET(key, "weekhonor", player_info.weekhonor)
	connect:HSET(key, "time", player_info.time)
	connect:EXPIRE(key, 30*24*60*60)
end	

local function RecordPlayerNums(uid, roomtype)
	local key = "gamemember"..roomtype..os.date("%Y%m%d")
	connect:SADD(key, uid)
end

local function UpdateTopListToRedis()
	if #top_score ~= 0 then
		if connect:exists(KEY.top_score) then
			connect:DEL(KEY.top_score)
		end
		for k, v in pairs(top_score) do
			connect:LPUSH(KEY.top_score, v.uid) --若key不存在，LPUSH会创建一个空表并插入数据
		end
	end
	if #top_money ~= 0 then
		if connect:exists(KEY.top_money) then
			connect:DEL(KEY.top_money)
		end
		for k, v in pairs(top_money) do
			connect:LPUSH(KEY.top_money, v.uid)
		end
	end
	if #top_dayhonor ~= 0 then
		if connect:exists(KEY.top_dayhonor) then
			connect:DEL(KEY.top_dayhonor)
		end
		for k, v in pairs(top_dayhonor) do
			connect:LPUSH(KEY.top_dayhonor, v.uid)
		end
	end
	if #top_weekhonor ~= 0 then
		if connect:exists(KEY.top_weekhonor) then
			connect:DEL(KEY.top_weekhonor)
		end
		for k, v in pairs(top_weekhonor) do
			connect:LPUSH(KEY.top_weekhonor, v.uid)
		end
--		for k, v in ipairs(top_weekhonor) do
--			print("DAY", k, v.uid)
--		end
	end
	updatetimer:remove()
	updatetimer:start(5*60*100, UpdateTopListToRedis)
end

local function InitOneTime()
	if connect:exists(KEY.last_onetime) then
		onetime = connect:get(KEY.last_onetime)
	end
end

local function UpdateOneTime(onetime)
	connect:SET(KEY.last_onetime, onetime)
end

local function InitLastWeekList()
	if connect:exists(KEY.last_weekhonor) then
		for i = 0, 19 do
			local result = connect:lindex(KEY.last_weekhonor, i)
			table.insert(lastw_playerinfos, result)
		end
	end
end

local function UpdateLastWeekList(lastw_playerinfos)
	if connect:exists(KEY.last_weekhonor) then
		connect:DEL(KEY.last_weekhonor)
	end
	for k, v in ipairs(lastw_playerinfos) do
		connect:LPUSH(KEY.last_weekhonor, v)
	end
end

local CompareScore = function(plr1, plr2)
	return plr1.score > plr2.score
end

local CompareMoney = function(plr1, plr2)
	return plr1.money > plr2.money
end

local CompareDayhonor = function(plr1, plr2)
	if (plr1.dayhonor == plr2.dayhonor) then
		return plr1.time < plr2.time
	else
		return plr1.dayhonor > plr2.dayhonor 
	end
end

local CompareWeekhonor = function(plr1, plr2)
	if (plr1.weekhonor == plr2.weekhonor) then
		return plr1.time < plr2.time
	else
		return plr1.weekhonor > plr2.weekhonor 
	end
end

local function UpdateTopList(player_info)
	for i = 1, 50 do
		if top_score[i] and top_score[i].uid == player_info.uid then
			table.remove(top_score, i)
		end
		if top_money[i] and top_money[i].uid == player_info.uid then
			table.remove(top_money, i)
		end
		if top_dayhonor[i] and top_dayhonor[i].uid == player_info.uid then
			table.remove(top_dayhonor, i)
		end
		if top_weekhonor[i] and top_weekhonor[i].uid == player_info.uid then
			table.remove(top_weekhonor, i)
		end
	end
	table.insert(top_dayhonor, player_info)
	table.insert(top_weekhonor, player_info)
	table.insert(top_score, player_info)
	table.insert(top_money, player_info)
	table.sort(top_score, CompareScore)
	table.sort(top_money, CompareMoney)
	table.sort(top_dayhonor, CompareDayhonor)
	table.sort(top_weekhonor, CompareWeekhonor)
--	for k, v in pairs(top_score) do
--		print(k, v.uid, v.score)
--	end
--	for k, v in pairs(top_money) do
--		print(k, v.uid, v.money)
--	end
--	for k, v in pairs(top_dayhonor) do
--		print("D", k, v.uid, v.dayhonor)
--	end
--	for k, v in pairs(top_weekhonor) do
--		print("W", k, v.uid, v.weekhonor)
--	end
	if #top_score > 50 then
		table.remove(top_score, #top_score)
	end
	if #top_money > 50 then
		table.remove(top_money, #top_money)
	end
	if #top_dayhonor > 50 then
		table.remove(top_dayhonor, #top_dayhonor)
	end
	if #top_weekhonor > 50 then
		table.remove(top_weekhonor, #top_weekhonor)
	end
end

local function GetTopList(key, by)
	local retlist = {}
	if connect:exists(key) then
		local str = string.format("%s desc by UINFO_LI*->%s get UINFO_LI*->uid get UINFO_LI*->money get UINFO_LI*->score get UINFO_LI*->info get UINFO_LI*->qq_vip get UINFO_LI*->vip", key, by)
		local players = connect:SORT(Explain(str))

		if players then
			local player = {}
			local num = 1
			for k, v in pairs(players) do
				if num == 1 then
					player.uid = tonumber(v)
				elseif num == 2 then
					player.money = tonumber(v)
				elseif num == 3 then
					player.score = tonumber(v)
				elseif num == 4 then
					player.info = v
				elseif num == 5 then
					player.qq_vip = tonumber(v)
				elseif num == 6 then
					player.vip = tonumber(v)
					table.insert(retlist, player)
					player = {}
					num = 0
				end
				num = num + 1
			end
		end
	end
	return retlist
end

local function GetTopList1(key, by)
	local retlist = {}
	if connect:exists(key) then
		local str = string.format("%s desc by UINFO_LI*->%s get UINFO_LI*->uid get UINFO_LI*->money get UINFO_LI*->score get UINFO_LI*->info get UINFO_LI*->qq_vip get UINFO_LI*->vip get UINFO_LI*->dayhonor get UINFO_LI*->weekhonor get UINFO_LI*->time", key, by)
--		print("@@@@@@@@@", str)
--		local a = {Explain(str)}
--		for k, v in pairs(a) do
--			print(k, v)
--		end
		local players = connect:SORT(Explain(str))
		if players then
			local player = {}
			local num = 1
			for k, v in pairs(players) do
				if num == 1 then
					player.uid = tonumber(v)
				elseif num == 2 then
					player.money = tonumber(v)
				elseif num == 3 then
					player.score = tonumber(v)
				elseif num == 4 then
					player.info = v
				elseif num == 5 then
					player.qq_vip = tonumber(v)
				elseif num == 6 then
					player.vip = tonumber(v)
				elseif num == 7 then
					player.dayhonor = tonumber(v)
				elseif num == 8 then
					player.weekhonor = tonumber(v)
				elseif num == 9 then
					player.time = tonumber(v)
					table.insert(retlist, player)
					player = {}
					num = 0
				end
				num = num + 1
			end
		end	 
	end
	return retlist
end

local function GetToolsConf()
	local retlist = {}
	local key = "SERVER_TOOL"
	if connect:exists(key) then
		local str = string.format("%s asc by *->tlid get *->tlid get *->type get *->vip get *->vday get *->m get *->mday get *->ct get *->cprc get *->mprc", key)
		local tools = connect:SORT(Explain(str))
		if tools then
			local tool = {}
			local num = 1
			for k, v in pairs(tools) do
				table.insert(tool, tonumber(v))
				if num == 9 then
					table.insert(retlist, tool)
					tool = {}
					num = 0
				end
				num = num + 1
			end
		end	 
	end
	return retlist
end

local function GetFriendTopList(uid, by)
	local key = "FRIEND_LIST"..uid
	local list = {}
	if not connect:exists(key) then
		local result = skynet.call("mysql", "lua", cmd.SQL_GET_FRIENDS, uid)
		if result and #result ~= 0 then
			for k, v in pairs(result) do
				connect:LPUSH(key, tonumber(v[1]))
			end
			connect:EXPIRE(key, 60*60)
		else
			return list
		end
	end
	return GetTopList(key, by)
end

command["record_game_num"] = function(body)
	local _, roomtype = unpack(body)
	local key = "gamecard"..roomtype..os.date("%Y%m%d")
	if connect:exists(key) then
		connect:incr(key)
	else
		connect:set(key, 1)
	end
end

command["record_player_num"] = function(body)
	local _, uid, roomtype = unpack(body)
	RecordPlayerNums(uid, roomtype)
end

command["login_key"] = function(body)
	local _, uid, key = unpack(body)
	local searchkey = "UKEY"..uid
	if not connect:exists(searchkey) or connect:get(searchkey) ~= key then
		skynet.ret(skynet.pack(false))
	else
		skynet.ret(skynet.pack(true))
	end
end

command["update_info"] = function(body)
	local _, player_info = unpack(body)
	UpdateInfo(player_info)
	UpdateTopList(player_info)
end

command["get_top_list"] = function(body)
	local _, uid, topid = unpack(body)
	local list = {}
	if topid == 1 then
		list = top_money
	elseif topid == 2 then
		list = top_score
	elseif topid == 3 then
		list = GetFriendTopList(uid, "money")
	elseif topid == 4 then
		list = GetFriendTopList(uid, "score")
	end
	skynet.ret(skynet.pack(list))
end

command["get_last_list"] = function(body)
	local list = {}
	list = lastw_playerinfos
	skynet.ret(skynet.pack(onetime, list))
end

command["get_honor_list"] = function(body)
	local _, uid, player_info= unpack(body)
--	UpdateInfo(player_info)
--	UpdateTopList(player_info)
	local listd = top_dayhonor
	local listw = top_weekhonor
	skynet.ret(skynet.pack(listd, listw))
end

command["update_login_num"] = function(body)
	local key = "CP_LOGIN_NUM"..os.date("%Y%m%d")
	if connect:exists(key) then
		connect:incr(key)
	else
		connect:set(key, 1)
	end
end

command["get_tools_conf"] = function(body)
	skynet.ret(skynet.pack(GetToolsConf()))
end

command["wishing_well_bet"] = function(body)
	local _, uid, betmoney, roomid = unpack(body)
	BetWishingWell(uid, betmoney, roomid)
end

command["wishing_reward"] = function(body)
	local _, uid, upling, sptype, roomid, name = unpack(body)
	local winmoney = WinWishingWell(uid, upling, sptype, roomid, name)
	skynet.ret(skynet.pack(winmoney))
end

command["get_wishing_win_list"] = function(body)
	skynet.ret(skynet.pack(wishing_win_list))
end

command["get_wishing_well"] = function(body)
	skyent.ret(skynet.pack(wishing_money))
end

local function FlushHonor()
		skynet.error(string.format("Flush top_dayhonor: time = %s", os.date()))
		top_dayhonor = {}
		if os.date("*t", os.time()).wday == 1 then
			onetime = tonumber(os.time())
			skynet.error(string.format("Flush top_weekhonor: time = %s", os.date()))
			list_weekhonor = {}
			lastw_playerinfos = {}
			list_weekhonor = top_weekhonor
			top_weekhonor = {}
			for k, v in ipairs(list_weekhonor) do
				if v.weekhonor > 0 then
					table.insert(lastw_playerinfos, v.info)
				end
			end
			UpdateLastWeekList(lastw_playerinfos)
			UpdateOneTime(onetime)
			skynet.send("CPCenter", "lua", cmd.EVENT_SEND_WEEKREWARD, list_weekhonor)
		end
end

command["a_new_day"] = function(body)
	FlushHonor()
end

local function Init()
	connect = redis.connect"main"
	top_score = GetTopList(KEY.top_score, "score")
	top_money = GetTopList(KEY.top_money, "money")
	top_dayhonor = GetTopList1(KEY.top_dayhonor, "dayhonor")
	top_weekhonor = GetTopList1(KEY.top_weekhonor, "weekhonor")
	updatetimer:start(5*60*100, UpdateTopListToRedis)
	InitWishingWinList()
	InitWishingWell()
	InitLastWeekList()
	InitOneTime()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local mtype = body[1]
		body[1] = address
		local f = command[mtype]
		if f then
			f(body)
		else
			print("unknow redis message", mtype)
		end
	end)
	Init()
--	connect:FLUSHDB()
	print("start myredis")
	skynet.register("myredis")
end)


