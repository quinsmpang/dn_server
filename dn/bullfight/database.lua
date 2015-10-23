local mysql = require "mysql"
local serverconf = require "serverconf"
local cmd = require "cmd"
local db = {}
require "gameprotobuf"
local protobuf = protobuf
local skynet = require "skynet"
local task = require "taskconf"
local types = require "types"
local GP = protobuf.proto.game.package
local winlog = {}
local command = {}
local string = string
local pairs = pairs
local table = table
local backmoney = {}
local backtime = os.time()
local all_title = {}
local notice 
local taskinfo = {}
local tool_title = {}
local update_activer = {}

local function test()
	for k, v in pairs(serverconf.DB_NAME) do
		db[k] = mysql.create()
		local ret = db[k]:connect(serverconf.DB_HOST, serverconf.DB_PORT, serverconf.DB_USER, serverconf.DB_PASSWORD, v)
		if not ret then
			skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("SQL connect error."))
			skynet.abort()
		end
	end
	print("step 1")
	local sql = string.format("insert into online set uid = %d, tid = %d", 1234, 4321)
	local ret = db[serverconf.DB_ID.member]:exec(sql)
	print("step 2")
	sql = string.format("select tid from online where uid = %d; select vip from qqvip where uid = %d", 1234, 23)
	local qresult = db[serverconf.DB_ID.member]:query(sql)
	print("step 3", qresult.pos)
	local res = qresult.nextresult()
	print("step 4")
	if res then
		for k, v in pairs(res) do
			print("################", k, v[1])
		end
	end
	res = qresult.nextresult()
	if res then
		for k, v in pairs(res) do
			print("################", k, v[1])
		end
	end
end

local function AddSlashes(str)
	local new = string.gsub(str, "\\", "\\\\")
	new = string.gsub(new, "\'", "\\\'")
	new = string.gsub(new, "\"", "\\\"")
	return new
end

local function WriteEmail(conf)
	local contant = nil
	if conf.type == 1 then --获得金币
		if task.name[conf.id] then
			contant = "您通过"..task.name[conf.id].."获得游戏币"..tostring(conf.money)
		elseif tool_title[conf.id] then
			contant = "您通过"..tool_title[conf.id].."获得游戏币"..tostring(conf.money)
		else
			if conf.money > 0 then
				contant = "系统赠送游戏币"..tostring(conf.money)
			else
				contant = "系统扣除游戏币"..tostring(conf.money)
			end
		end
	elseif conf.type == 2 then --获得道具
		if conf.fid == 0 then
			if tool_title[conf.id] then
				contant = "系统赠送给您"..tool_title[conf.id]..",数量:"..tostring(conf.count)
			end
		elseif conf.uid == conf.fid then
			if tool_title[conf.id] then
				contant = "您获得了"..tool_title[conf.id]..",数量:"..tostring(conf.count)
			end
		else
			local sql = string.format("select nickname from dt_member_platform%d where uid = %d", conf.fid, conf.fid)
			local result = db[serverconf.DB_ID.dt_member]:query(sql)
			if result and #result ~= 0 and tool_title[conf.id] then
				contant = result[1][1].."赠送给您"..tool_title[conf.id]..",数量:"..tostring(conf.count)
			end
		end

	elseif conf.type == 3 then --获得牛粪
		if task.name[conf.id] then
			contant = "您通过"..task.name[conf.id].."获得牛粪"..tostring(conf.dtmoney).."桶"
		elseif tool_title[conf.id] then
			contant = "您通过"..tool_title[conf.id].."获得牛粪"..tostring(conf.dtmoney).."桶"
		else
			if conf.dtmoney > 0 then
				contant = "系统赠送牛粪"..tostring(conf.dtmoney).."桶"
			else
				contant = "系统扣除牛粪"..tostring(conf.dtmoney).."桶"
			end
		end
	end
	if contant then
		contant = AddSlashes(contant)
		local sql = string.format("insert into dt_member_msg%d set tuid = %d, mtype = %d, status = %d, message = '%s', atime = %d",
			conf.uid%100, conf.uid, 2, 0, contant, os.time())
		local ret = db[serverconf.DB_ID.dt_member_log]:exec(sql)
		if conf.type == 2 and conf.money and conf.money ~= 0 then
			conf.type = 1
			WriteEmail(conf)
		end
	end
end

local function InitDayTaskinfo()
	local language = serverconf.language
	local sql= string.format("select dtid, cont, cont_th, cont_en, title, title_th, title_en, dtval, dtchip, dtcoin, dtlottery, dttool, dttype")
	local result = db[serverconf.DB_ID.member]:query(sql)
	if result and #result ~= 0 then
		for k, v in pairs(result) do
			local tid = tonumber(resultv[1])
			taskinfo[tid] = {
				taskid = tid
				
			}
		end
	end
end

local function UpdateNotice()
	local sql = string.format("select nid, nname, nfdate, ntodate, ntype, ncont, adminid from dt_notice where ntodate >= %d and nflag = %d and ntype = %d",
		tonumber(os.date("%Y%m%d")), 0, 2)
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	if result then
		local notices = {}
		if #result ~= 0 then
			for k, v in pairs(result) do
				local edate = tonumber(v[4])
				if edate >= tonumber(os.date("%Y%m%d")) then
					local nt = protobuf.pack(GP..".notice id name sdate edate type content", 
						tonumber(v[1]), v[2], tonumber(v[3]), edate, tonumber(v[5]), v[6])
					table.insert(notices, nt)
				end
			end
		end
		local packet = protobuf.pack(GP..".SMSG_UPDATE_NOTICE notices", notices)
		notice = protobuf.pack(GP..".Packet type body", cmd.SMSG_UPDATE_NOTICE, packet)
	else
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("SQL get notice error."))
		notice = nil
	end
end	

local function GetAllTitle()
	local sql = string.format("select id, name_cn, name_th, name_en, integral from designation")
	local result = db[serverconf.DB_ID.member]:query(sql)
	if result and #result ~= 0 then
		all_title = result
		for k, v in pairs(all_title) do
			v[5] = tonumber(v[5])
		end
	else
		print("get title error")
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("SQL get all_title error."))
	end
end

local function GetTitle(score)
	if not score then
		return tostring(0)
	end
	if #all_title == 0 then
		GetAllTitle()
	end
	local title
	if score < all_title[1][5] then
		title = all_title[1][serverconf.language]
	else
		for i = 1, #all_title - 1 do
			if score >= all_title[i][5] and score < all_title[i + 1][5] then
				title = all_title[i][serverconf.language]
			end
		end
	end
	if score >= all_title[#all_title][5] then
		title = all_title[#all_title][serverconf.language]
	end
	return title
end

local function Init()
	for k, v in pairs(serverconf.DB_NAME) do
		db[k] = mysql:create()
		local ret = db[k]:connect(serverconf.DB_HOST, serverconf.DB_PORT, serverconf.DB_USER, serverconf.DB_PASSWORD, v)
		if not ret then
			skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("SQL connect error."))
			skynet.abort()
		end
	end
	if not serverconf.TEST_MODEL then
		for i = 0, 99 do
			local sql = string.format("update dt_member%d set isonline = %d", i, 0)
			db[serverconf.DB_ID.dt_member]:exec(sql)
		end
	end
	GetAllTitle()
	UpdateNotice()
end

local function WriteWinLog(roomid, insertid)
	local time = os.time()
	if winlog[roomid] and insertid then
		for k, v in pairs(winlog[roomid]) do
			local sql = string.format("insert into winlog set tlid = %d, uid = %d, tid = %d, wlfold = %d, wlleft = %d, wlwin = %d, wltime = %d", 
			insertid, v.uid, v.roomid, v.escape, v.leftmoney, v.winmoney, time)
			db[serverconf.DB_ID.log]:exec(sql)
		end
	end
	winlog[roomid] = {}
end

local function GetPfid(uid)
	local mysql = db[serverconf.DB_ID.dt_member]
	local sql = string.format("select pfid from dt_member_platform%d where uid = %d", uid%100, uid)
	local pfid = mysql:query(sql)
	if pfid and #pfid ~= 0 then
		pfid = tonumber(pfid[1][1])
	else
		pfid = nil
	end
	sql = string.format("select platfrom from dt_member_platform%d where uid = %d", uid%100, uid)
	local platfrom = mysql:query(sql)
	if platfrom and #platfrom ~= 0 then
		platfrom = tonumber(platfrom[1][1])
	else
		platfrom = nil
	end

	return pfid, platfrom
end

command[cmd.SQL_TABLE_LOG] = function(msg)
--	local sql = string.format("insert delayed into dt_member_card set cardsid = %d, uid = '%s', `describe` = '%s'",
	local sql = string.format("insert into dt_member_card set cardsid = %d, uid = '%s', `describe` = '%s'",
	msg.cardsid, msg.playersid, msg.log)
	db[serverconf.DB_ID.dt_member_log]:exec(sql)
end

command[cmd.SQL_MONEY_LOG] = function(msg)
	local sql = string.format("insert into  dt_member_gold set uid = %d, changegold = %d, curgold = %d, time = %d, typeid = %d, assistid = %d, pfid = %d",
	msg.uid, msg.addmoney, msg.curmoney, os.time(), msg.typeid, msg.assistid, msg.pfid)
	db[serverconf.DB_ID.dt_member_log]:exec(sql)
end

command[cmd.SQL_DTMONEY_LOG] = function(msg)
--	local sql = string.format("insert delayed into  dt_member_cow set uid = %d, changecow = %f, curcow = %f, time = %d, typeid = %d, assistid = %d",
	local sql = string.format("insert into  dt_member_cow set uid = %d, changecow = %f, curcow = %f, time = %d, typeid = %d, assistid = %d, pfid = %d",
	msg.uid, msg.addcow, msg.curcow, os.time(), msg.typeid, msg.assistid, msg.pfid)
	db[serverconf.DB_ID.dt_member_log]:exec(sql)
end

command[cmd.SQL_WIN_LOG] = function(msg)
	local roomid = msg.roomid
	if not winlog[roomid] then
		winlog[roomid] = {}
	end
	table.insert(winlog[roomid], msg)
end

command[cmd.SQL_TASK_NEW_PLAYER] = function(uid)
	local sql = string.format("select miguide from mission where uid = %d", uid)
	local result = db[serverconf.DB_ID.member]:query(sql)
	local ret = false
	if result then
		if #result == 0 or (#result ~= 0 and tonumber(result[1][1]) == 0) then
			ret = true
			sql = string.format("insert into mission set uid = %d, miguide = %d, milevel3 = %d, milevel5 = %d, miinvite5 = %d ON DUPLICATE KEY UPDATE miguide = %d",
				uid, 1, 0, 0, 0, 1)
				db[serverconf.DB_ID.member]:exec(sql)
		end
	end
	skynet.ret(skynet.pack(ret))
end

command[cmd.SQL_SYSTEM_ERROR] = function(msg)
	msg.errors = AddSlashes(msg.errors)
	msg.env = AddSlashes(msg.env)
	local sql = string.format("insert into errorlog set euid = %d, errors = '%s', env = '%s', edate = %d",
	msg.uid, msg.errors, msg.env, os.time())
	db[serverconf.DB_ID.log]:exec(sql)
end

command[cmd.SQL_UPDATE_PLAYERCONF] = function(msg)
	local sql = string.format("update dt_member_game%d set gamecurrency = gamecurrency + %d, uscore = uscore + %d,uwincnt = uwincnt +%d, ulosecnt = ulosecnt + %d, udrawcnt = udrawcnt +%d, monthwin = %d, monthlose = %d, monthdraw = %d, daywin = %d, daylose = %d, daydraw = %d, date = %d, besttype = %d, dtmoney = dtmoney + %f, dayhonor = %d, weekhonor = %d where uid = %d",
	msg.uid%100, msg.upmoney, msg.upscore, msg.upwincount, msg.uplosecount, msg.updrawcount, 
	msg.monthwin, msg.monthlose, msg.monthdraw, msg.daywin, msg.daylose,
	msg.daydraw, msg.date, msg.besttype, msg.updtmoney, msg.dayhonor, msg.weekhonor, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_GET_LOGIN_KEY] = function(uid)
	local sql = string.format("select olkey from online where uid = %d", uid)
	local result = db[serverconf.DB_ID.member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_PLAYERCONF] = function(uid)
	local sql = string.format("SELECT gamecurrency,uscore,uwincnt,ulosecnt,udrawcnt,monthwin,monthlose,monthdraw,daywin,daylose,daydraw,date,qqvip, besttype, dtmoney, dayhonor, weekhonor, gametime, redpackettime FROM dt_member_game%d WHERE uid=%d", uid%100, uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_ROOMCONF] = function(msg)
	local sql = string.format("select tid, ttype, tseat, tmax, tbasebet, tminchip, tmaxchip, tticket, tfee, tseconds, tmethod, tstatus, tbanker from `table`")
	local result = db[serverconf.DB_ID.member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_FRIENDS] = function(uid)
	local sql = string.format("SELECT fuid FROM dt_member_friend%d WHERE uid = %d AND ftype != 2", uid % 100, uid)
	local result = db[serverconf.DB_ID.dt_relation]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_ALL_GOODS] = function()
	local sql = string.format("select id, `describe`, `type`, isshow, img, title, price, coin from dt_tool where isshow = 1")
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	local copy = result
	if copy and #copy ~= 0 then
		for k, v in pairs(copy) do
			local id = tonumber(v[1])
			tool_title[id] = v[6]
		end
	end
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_BACK_MONEY] = function(msg)
	if not backmoney[msg.gametype] then
		backmoney[msg.gametype] = {}
	end
	if not backmoney[msg.gametype][msg.moneytype] then
		backmoney[msg.gametype][msg.moneytype] = {money = 0}
	end
	backmoney[msg.gametype][msg.moneytype].roomtype = msg.roomtype
	backmoney[msg.gametype][msg.moneytype].pfid = msg.pfid
	backmoney[msg.gametype][msg.moneytype].money = backmoney[msg.gametype][msg.moneytype].money + msg.money
--	if backtime + 60 * 60 < os.time() then -- 一个小时统计一次，这个不需要实时记录
	if backtime <= os.time() then 
		backtime = os.time()
		for k, v in pairs(backmoney) do
			for i, j in pairs(v) do
				if j.money ~= 0 then
					local sql = string.format("insert into dt_bakcount set bktime = %d, bkgtype = %d, bkgmtype = %d, bkrtype = %d, bkmoney = %d, pfid = %d", backtime, k, i, j.roomtype, j.money, j.pfid)
					local mysql = db[serverconf.DB_ID.dt_common]
					if mysql:exec(sql) then
						j.money = 0
					else
						skynet.send("CPLog", "lua", cmd.ERROR_LOG, string.format("SQL backmoney error, %s-%s", ret, mysql.error()))
					end
				end
			end
		end
	end
end

command[cmd.SQL_UPDATE_ACTIVER] = function(msg)
	local sql = string.format("INSERT INTO dt_coincount SET ucdate = %d ,upfid = %d, ucactive = %d ON DUPLICATE KEY UPDATE ucactive = ucactive + %d", msg.date, msg.pfid, 1, 1)
	db[serverconf.DB_ID.dt_common]:exec(sql)
	sql = string.format("select sum(ucactive) from dt_coincount where ucdate = %d and upfid != 0", msg.date)
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	if result and #result ~= 0 then
		local sum = tonumber(result[1][1])
		sql = string.format("INSERT INTO dt_coincount SET ucdate = %d ,upfid = %d, ucactive = %d ON DUPLICATE KEY UPDATE ucactive = %d", msg.date, 0, sum, sum)
		db[serverconf.DB_ID.dt_common]:exec(sql)
	end
end

command[cmd.SQL_GET_PFID] = function(uid)
	local pfid, platfrom = GetPfid(uid)
	local sqlpfid = 0
	if not platfrom then
		platfrom = 0
	end
	if platfrom > 0 then
		sqlpfid = pfid * 100 + platfrom
	else
		sqlpfid = pfid
	end
	skynet.ret(skynet.pack(sqlpfid))
end

command[cmd.SQL_ADMIN_ADD_MONEY] = function(msg)
	local succ = true
	local money = 0
	local sqlpfid = 0
	local mysql = db[serverconf.DB_ID.dt_member]
	local sql = string.format("select gamecurrency from dt_member_game%d where uid = %d", msg.uid%100, msg.uid)
	local result = mysql:query(sql)
	if result and #result ~= 0 then
		money = tonumber(result[1][1])
		if money < -msg.money then
			succ = false
		end
	else
		succ = false
	end
	if succ then
		sql = string.format("update dt_member_game%d set gamecurrency = gamecurrency + %d where uid = %d", msg.uid%100, msg.money, msg.uid)
		if not mysql:exec(sql) then
			succ = false
		end
	end
	if not succ then
		local log = string.format("admin add money error,player:%d, addid:%d, money:%d", msg.uid, msg.addid, msg.money)
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, log)
	end
	local pfid, platfrom = GetPfid(msg.uid)
	local sqlpfid = 0
	if not platfrom then
		platfrom = 0
	end
	if platfrom > 0 then
		sqlpfid = pfid * 100 + platfrom
	else
		sqlpfid = pfid
	end
	skynet.ret(skynet.pack(succ, money, sqlpfid))
end

command[cmd.SQL_ADMIN_ADD_DTMONEY] = function(msg)
	local succ = true
	local dtmoney = 0
	local sqlpfid = 0
	local mysql = db[serverconf.DB_ID.dt_member]
	local sql = string.format("select dtmoney from dt_member_game%d where uid = %d", msg.uid%100, msg.uid)
	local result = mysql:query(sql)
	if result and #result ~= 0 then
		dtmoney = tonumber(result[1][1])
		if dtmoney < -msg.dtmoney then
			succ = false
		end
	else
		succ = false
	end
	if succ then
		sql = string.format("update dt_member_game%d set dtmoney = dtmoney + %d where uid = %d", msg.uid%100, msg.dtmoney, msg.uid)
		if not mysql:exec(sql) then
			succ = false
		end
	end
	if not succ then
		local log = string.format("admin add dtmoney error,player:%d, addid:%d, dtmoney:%d", msg.uid, msg.addid, msg.dtmoney)
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, log)
	end
	local pfid, platfrom = GetPfid(msg.uid)
	local sqlpfid = 0
	if not platfrom then
		platfrom = 0
	end
	if platfrom > 0 then
		sqlpfid = pfid * 100 + platfrom
	else
		sqlpfid = pfid
	end
	skynet.ret(skynet.pack(succ, dtmoney, sqlpfid))
end

command[cmd.SQL_SHOP] = function(msg)
	local errn = 0
	local insertid = {}
	local s = string.format("select gamecurrency from dt_member_game%d where uid = %d", msg.uid%100, msg.uid)
	local r = db[serverconf.DB_ID.dt_member]:query(s)
	if not r or #r == 0 then
		skynet.ret(skynet.pack(false, insertid))
		return 0
	end
	if msg.todb then
		msg.resean = AddSlashes(msg.resean)
		local mysql = db[serverconf.DB_ID.dt_common]
		if msg.kind == 1 or msg.kind == 5 or msg.kind == 6 then
			local stime = 0
			local sql = string.format("select utime from dt_member_tool where uid = %d and tid = %d and status = %d", msg.uid, msg.goodsid, 1)
			local result = mysql:query(sql)
			if result then
				if #result ~= 0 then
					for k, v in pairs(result) do
						local t = tonumber(v[1])
						if stime < t and t + msg.lasttime > os.time() then
							stime = t
						end
					end
				end
			end
			if stime == 0 then -- 数据库没有未过期的1 5 6类道具，stime设置为现在
				stime = os.time()
			else -- 数据库有正在使用且未过期的1 5 6类道具，stime设置为道具过期的时间点
				stime = stime + msg.lasttime
			end
			for i = 1, msg.count do
				sql = string.format("insert into dt_member_tool set uid = %d, fromuid = %d, tid = %d, status = %d, atime = %d, utime = %d, num = %d, remark = '%s'",
			msg.uid, msg.fid, msg.goodsid, msg.status, os.time(), stime, msg.num, msg.resean)
				if not mysql:exec(sql) then
					errn = errn + 1
				else
					stime = stime + msg.lasttime
					table.insert(insertid, mysql.insertid())
				end
			end
		else
			local sql = string.format("insert into dt_member_tool set uid = %d, fromuid = %d, tid = %d, status = %d, atime = %d, utime = %d, num = %d, remark = '%s'",
				msg.uid, msg.fid, msg.goodsid, msg.status, os.time(), msg.stime, msg.num, msg.resean)
			for i = 1, msg.count do
				if not mysql:exec(sql) then
					errn = errn + 1
				else
					table.insert(insertid, mysql.insertid())
				end
			end
		end
	end
	local shopret = true
	if errn ~= 0 and shopret then
		local log = string.format("sql_error, count %d :%s", errn, sql)
		skynet.send("CPLog", cmd.ERROR_LOG, log)
		shopret = false
	else
		local mysql = db[serverconf.DB_ID.dt_member]
		if msg.money and msg.money ~= 0 then
			local sql = string.format("update dt_member_game%d set gamecurrency = gamecurrency + %d where uid = %d",
				msg.uid%100, msg.money, msg.uid)
			if not mysql:exec(sql) then
				shopret = false
			else
				sql = string.format("select gamecurrency from dt_member_game%d where uid = %d", msg.uid%100, msg.uid)
				local result = mysql:query(sql)
				local pfid, platfrom = GetPfid(msg.uid)
				local sqlpfid = 0
				if not platfrom then
					platfrom = 0
				end
				if platfrom > 0 then
					sqlpfid = pfid * 100 + platfrom
				else
					sqlpfid = pfid
				end
				if result and #result ~= 0 then
					local log = {
						uid = msg.uid,
						typeid = msg.goodsid,
						addmoney = msg.money,
						curmoney = tonumber(result[1][1]),
						assistid = 0,
						pfid = sqlpfid
						}
			--		skynet.send("CPLog", "lua", cmd.MONEY_LOG, log)
					command[cmd.SQL_MONEY_LOG](log)
				end
			end
		end
	end
	if shopret and msg.order_nu then
		local sql = string.format("update dt_member_recharge set responsestatus = %d where orderid = '%s'",
			3, msg.order_nu)
		local mysql = db[serverconf.DB_ID.dt_common]
		if not mysql:exec(sql) then
			local log = string.format("sql_error:%s-%s", sql, mysql.error())
			skynet.send("CPLog", cmd.ERROR_LOG, log)
		end
	end
	skynet.ret(skynet.pack(shopret, insertid))
	if shopret then
		local m = {uid = msg.uid, fid = msg.fid, id = msg.goodsid, type = 2, money = msg.money, count = msg.count}
		WriteEmail(m)
	end
end

command[cmd.SQL_GET_BLOCKED_PLAYER] = function(msg)
	local sql = string.format("select uid, etime from dt_member_blacklist where etime > %d", os.time())
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_ADD_FRIEND] = function(msg)
	local sql_a = string.format("INSERT IGNORE INTO dt_member_friend%d SET uid = %d, fuid = %d, ftype = %d",
	msg.uid % 100, msg.uid, msg.fid, 1)
	local sql_b = string.format("INSERT IGNORE INTO dt_member_friend%d SET uid = %d, fuid = %d, ftype = %d",
	msg.fid % 100, msg.fid, msg.uid, 1)
	db[serverconf.DB_ID.dt_relation]:exec(sql_a)
	db[serverconf.DB_ID.dt_relation]:exec(sql_b)
end

command[cmd.SQL_DEL_FRIEND] = function(msg)
	local sql_a = string.format("delete from dt_member_friend%d where uid = %d and fuid = %d", msg.uid % 100, msg.uid, msg.fid)
	local sql_b = string.format("delete from dt_member_friend%d where uid = %d and fuid = %d", msg.fid % 100, msg.fid, msg.uid)
	db[serverconf.DB_ID.dt_relation]:exec(sql_a)
	db[serverconf.DB_ID.dt_relation]:exec(sql_b)
end

command[cmd.SQL_GET_SAFE_BOX] = function(uid)
	local sql = string.format("select gamecurrency, pwd, question, answer from dt_safe_box where uid = %d", uid)
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	skynet.ret(skynet.pack(result))
end
	
command[cmd.SQL_UPDATE_SAFE_BOX] = function(msg)
	local sql = string.format("insert into dt_safe_box set uid = %d, gamecurrency = %d, pwd = '%s', question = '%s', answer = '%s', atime = %d ON DUPLICATE KEY UPDATE gamecurrency = gamecurrency + %d, pwd = '%s', question = '%s', answer = '%s'",
	msg.uid, msg.money, msg.pwd, msg.question, msg.answer, os.time(),
	msg.upmoney, msg.pwd, msg.question, msg.answer)
	db[serverconf.DB_ID.dt_common]:exec(sql)
end

command[cmd.SQL_GET_TITLE] = function(score)
	local title = GetTitle(score)
	skynet.ret(skynet.pack(title))
end

command[cmd.SQL_USE_TOOL] = function(msg)
	local sql = string.format("update dt_member_tool set status = %d, utime = %d where id = %d", msg.status, os.time(), msg.id)
	db[serverconf.DB_ID.dt_common]:exec(sql)
end

command[cmd.SQL_GET_TASKCONF] = function(msg)
	local sql = string.format("select taskid, num from taskconf where uid = %d and date = %d", msg.uid, tonumber(os.date("%Y%m%d")))
	local result = db[serverconf.DB_ID.member]:query(sql)
	local taskconf = {}
	if result and #result ~= 0 then
		for k, v in pairs(result) do
			local taskid = tonumber(v[1])
			local num = tonumber(v[2])
			taskconf[taskid] = {taskid = taskid, num = num, date = tonumber(os.date("%Y%m%d"))}
		end
	end
	if not taskconf[task.id.play_5] or not taskconf[task.id.learn_course] or not taskconf[task.id.qq_vip_course] then
		sql = string.format("select taskid, num, date from taskconf where uid = %d and (taskid = %d or taskid = %d or taskid = %d)", msg.uid, task.id.play_5, task.id.learn_course, task.id.qq_vip_course)
		result = db[serverconf.DB_ID.member]:query(sql)
		if result and #result ~= 0 then
			for k, v in pairs(result) do
				local taskid = tonumber(v[1])
				local num = tonumber(v[2])
				local date = tonumber(v[3])
				taskconf[taskid] = {taskid = taskid, num = num, date = date}
			end
		end
	end
	skynet.ret(skynet.pack(taskconf))
end

command[cmd.SQL_GET_PLAYER_GAMEINFO] = function(uid)
	local sql = string.format("SELECT gamecurrency,uscore,uwincnt,ulosecnt,udrawcnt FROM dt_member_game%d WHERE uid=%d", uid%100, uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	if result and #result ~= 0 then
		local conf = {uid = uid, money = tonumber(result[1][1]),
			score = tonumber(result[1][2]), wincount = tonumber(result[1][3]), 
			losecount = tonumber(result[1][4]), drawcount = tonumber(result[1][5])}
		conf.title = GetTitle(conf.score)
		conf.vip = 0
		skynet.ret(skynet.pack(conf))
	else
		skynet.ret(skynet.pack(nil))
	end
end

command[cmd.SQL_GET_SELF_TOOLS] = function(uid)
	local sql = string.format("select tid, status, utime, num, id from dt_member_tool where uid = %d and status != %d", uid, 2)	
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_LOGIN_CONF] = function(uid)
	local sql = string.format("select lasttime, loginnum, firstlogintime, loginreward from dt_member%d where uid = %d", uid%100, uid)
	local mysql = db[serverconf.DB_ID.dt_member]
	local result = mysql:query(sql)
	local task_new = true
	if not result then
		local log = string.format("sql_error:%s-%s", sql, mysql.error())
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, log)
	else
		sql = string.format("select miguide from mission where uid = %d", uid)
		local result = db[serverconf.DB_ID.member]:query(sql)
		if result then
			if #result == 0 or (#result ~= 0 and tonumber(result[1][1]) == 0) then
				task_new = false
			end
		end
	end
	sql = string.format("select nickname from dt_member_platform%d where uid = %d", uid%100, uid)
	local name = mysql:query(sql)
	if name and #name ~= 0 then
		name = name[1][1]
	else
		name = uid
	end
	sql = string.format("select header from dt_member_platform%d where uid = %d", uid%100, uid)
	local header = mysql:query(sql)
	if header and #header ~= 0 then
		header = header[1][1]
	else
		header = nil
	end
	local pfid, platfrom = GetPfid(uid)
	skynet.ret(skynet.pack(result, task_new, name, header, pfid, platfrom))
end

command[cmd.SQL_UPDATE_LOGIN_CONF] = function(msg)
	local sql = string.format("update dt_member%d set lasttime = %d, isonline = %d, loginnum = %d, firstlogintime = %d, loginreward = %d where uid = %d",
	msg.uid%100, msg.lasttime, 1, msg.loginnum, msg.firstlogintime, msg.loginreward, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_LOGIN_OUT] = function(uid)
	local sql = string.format("update dt_member%d set isonline = %d where uid = %d", uid%100, 0, uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_UPDATE_TOOLS] = function(msg)
	for k, v in pairs(msg) do
		local sql = string.format("update dt_member_tool set status = %d, num = %d where id = %d", v.status, v.num, v.id)
		db[serverconf.DB_ID.dt_common]:exec(sql)
	end
end

command[cmd.SQL_GET_ORDER] = function(order_nu)
	local sql = string.format("select uid, goodsid, ordertype, goodsprice, goodsnum, suid from dt_member_recharge where orderid = '%s' and responsestatus != %d", order_nu, 3)
	local mysql = db[serverconf.DB_ID.dt_common]
	local result = mysql:query(sql)
	if not result then
		local log = string.format("sql_error:%s-%s", sql, mysql.error())
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, log)
	end
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_NOTICE] = function(body)
	if notice == nil then
		UpdateNotice()
	end
	skynet.ret(skynet.pack(notice))
end

command[cmd.SQL_UPDATE_NOTICE] = function(body)
	UpdateNotice()
	skynet.ret(skynet.pack(notice))
end

command[cmd.SQL_BLOCKED_PLAYER] = function(msg)
	msg.resean = AddSlashes(msg.resean)
	local sql = string.format("insert into dt_member_blacklist set uid = %d, stime = %d, etime = %d, remark = '%s', isstop = %d, adminid = %d, atime = %d ON DUPLICATE KEY UPDATE stime = %d, etime = %d, remark = '%s', isstop = %d, adminid = %d, atime = %d",
	msg.uid, msg.starttime, msg.endtime, msg.resean, msg.state, msg.adminid, os.time(),
	msg.starttime, msg.endtime, msg.resean, msg.state, msg.adminid, os.time())
	if not db[serverconf.DB_ID.dt_common]:exec(sql) then
		skynet.ret(skynet.pack(false))
	else
		skynet.ret(skynet.pack(true))
	end
end

command[cmd.SQL_ADMIN_CHANGE_SF_PWD] = function(msg)
	local sql = string.format("update dt_safe_box set pwd = '%s' where uid = %d", msg.pwd, msg.uid)
	if not db[serverconf.DB_ID.dt_common]:exec(sql) then
		skynet.ret(skynet.pack(false))
	else
		skynet.ret(skynet.pack(true))
	end
end

command[cmd.SQL_WRITE_SYSTEM_EMAIL] = function(msg)
	WriteEmail(msg)
end

command[cmd.SQL_ON_LINE_LOG] = function(num)
--	local sql = string.format("insert delayed into dt_online_count set atime = %d, num = %d", os.time(), num)
	for k, v in pairs(num) do
		local sql = string.format("insert into dt_online_count set atime = %d, num = %d, pfid = %d", os.time(), v, k)
		db[serverconf.DB_ID.dt_common]:exec(sql)
	end
end

command[cmd.SQL_COMPLETE_TASK] = function(msg)
	local sql
	local date = tonumber(os.date("%Y%m%d"))
	local num = 0
	local ret = false
	local flag = 0
	if msg.taskid == task.id.play_5 or msg.taskid == task.id.qq_vip_course or msg.taskid == task.id.learn_course then
		sql = string.format("select num, date from taskconf where uid = %d and taskid = %d", msg.uid, msg.taskid)
		local result = db[serverconf.DB_ID.member]:query(sql)
		if result then
			if #result ~= 0 then
				num = tonumber(result[1][1])
				if date ~= tonumber(result[1][2]) and num < task.count[msg.taskid] then
					num = num + 1
					ret = true
				end
			else
				ret = true
				num = 1
				flag = 1
			end
		end
	else
		if msg.taskid == task.id.qq_vip or msg.taskid == task.id.microblog then
			sql = string.format("select num from taskconf where uid = %d and (taskid = %d or taskid = %d) and date = %d", msg.uid, task.id.qq_vip, task.id.microblog, msg.date)
		else
			sql = string.format("select num from taskconf where uid = %d and taskid = %d and date = %d", msg.uid, msg.taskid, msg.date)
		end
			local result = db[serverconf.DB_ID.member]:query(sql)
			if result then 
				if #result == 0 then
					ret = true
					num = 1
					flag = 1
				else
					num = tonumber(result[1][1])
					if num < task.count[msg.taskid] then
						ret = true
						num = num + 1
					end
				end
			end
	end
	if ret then
		if num == 1 and flag == 1 then
			sql = string.format("insert into taskconf set uid = %d, taskid = %d, num = %d, date = %d, pfid = %d", msg.uid, msg.taskid, num, date, msg.pfid)
		else
			sql = string.format("update taskconf set num = %d where date = %d and uid = %d and taskid = %d", num, date, msg.uid, msg.taskid)
		end
		if not db[serverconf.DB_ID.member]:exec(sql) then
			ret = false
		end
	end
	skynet.ret(skynet.pack(ret, num))
end

command[cmd.SQL_GET_PLAYNUM] = function(msg)
	local date = tonumber(os.date("%Y%m%d"))
	local sql = string.format("select daywinnum, daylosenum, daydrawnum, dayscore, daymoney from dt_userlog where uid = %d and ttype = %d and date = %d", msg.uid, msg.ttype, date)
	local result = db[serverconf.DB_ID.member]:query(sql)	
	skynet.ret(skynet.pack(result))	
end

command[cmd.SQL_UPDATE_PLAYNUM] = function(msg)
	local date = tonumber(os.date("%Y%m%d"))
	local sql
	local sql = string.format("select daywinnum, daylosenum, daydrawnum from dt_userlog where uid = %d and ttype = %d and date = %d", msg.uid, msg.ttype, msg.date)
	local result = db[serverconf.DB_ID.member]:query(sql)
	if result then
		if #result == 0 then
			sql = string.format("insert into dt_userlog set uid = %d, ttype = %d, daywinnum = %d, daylosenum = %d, daydrawnum = %d, date = %d, dayscore = %d, daymoney = %d, pfid = %d", msg.uid, msg.ttype, msg.daywinnum, msg.daylosenum, msg.daydrawnum, msg.date, msg.dayscore, msg.daymoney, msg.pfid)
		else
			sql = string.format("update dt_userlog set daywinnum = %d, daylosenum = %d, daydrawnum = %d, dayscore = %d, daymoney = daymoney + %d  where uid = %d and ttype = %d and date = %d", msg.daywinnum, msg.daylosenum, msg.daydrawnum, msg.dayscore, msg.daymoney, msg.uid, msg.ttype, msg.date)
		end
	end
	db[serverconf.DB_ID.member]:exec(sql)
end

command[cmd.SQL_GET_COWDUNG] = function(uid)
	local sql = string.format("SELECT dtmoney FROM dt_member_game%d WHERE uid=%d", uid%100, uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_UPDATE_COWDUNG] = function(msg)
	local sql = string.format("update dt_member_game%d set dtmoney = %f where uid = %d", msg.uid%100, msg.dtmoney, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_INSERT_EXCHANGE_INFO] = function(msg)
	local sql = string.format("insert into dt_member_change set uid = %d, platform = %d, goodsid = %d, goodsprice = %d, goodsnum = %d, money = %d, suid = %d, status = %d, time = %d", msg.uid, msg.platform, msg.goodsid, msg.price, msg.num, msg.money, msg.suid, msg.status, msg.time)
	db[serverconf.DB_ID.member]:exec(sql)
end

command[cmd.SQL_GET_PTYPENUM] = function(msg)
	local sql = string.format("select num from dt_ptype_num where uid = %d and ptype = %d and date = %d", msg.uid, msg.ptype, msg.date)
	local result = db[serverconf.DB_ID.member]:query(sql)
	skynet.ret(skynet.pack(result))	
end

command[cmd.SQL_UPDATE_PTYPENUM] = function(msg)
	local sql = string.format("select num from dt_ptype_num where uid = %d and ptype = %d and date = %d", msg.uid, msg.ptype, msg.date)
	local result = db[serverconf.DB_ID.member]:query(sql)
	if result then
		if #result == 0 then
			sql = string.format("insert into dt_ptype_num set uid = %d, ptype = %d, date = %d, num = %d, pfid = %d", msg.uid, msg.ptype, msg.date, msg.ptypenum, msg.pfid)
		else
			sql = string.format("update dt_ptype_num set num = %d where uid = %d and ptype = %d and date = %d", msg.ptypenum, msg.uid, msg.ptype, msg.date)
		end
	end
	db[serverconf.DB_ID.member]:exec(sql)
end

command[cmd.SQL_FLUSH_WEEKHONOR] = function()
	local sql = string.format("update dt_member_game set weekhonor = %d", 0)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_FLUSH_DAYHONOR] = function()
	local sql = string.format("update dt_member_game set dayhonor = %d", 0)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_GET_MONEY_VALUE] = function(uid)
	local sql = string.format("select gamecurrency from dt_member_game where uid = %d", uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	local pfid, platfrom = GetPfid(uid)
	skynet.ret(skynet.pack(result, pfid, platfrom))
end

command[cmd.SQL_SEND_MONEY] = function(msg)
	local sql = string.format("update dt_member_game set gamecurrency = gamecurrency + %d where uid = %d", msg.upmoney, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_GET_ALL_GIRLS] = function(msg)
	local sql = string.format("select uid from dt_member_platform where status != 0 and sex != 1")
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_ONLINE_INFO] = function(uid)
	local sql = string.format("select nickname, header,sex from dt_member_platform%d where uid = %d and status != 0", uid%100, uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_GET_ONLINE_GAMEINFO] = function(uid)
	local sql = string.format("select gamecurrency, uscore from dt_member_game%d where uid = %d", uid%100, uid)
	local result = db[serverconf.DB_ID.dt_member]:query(sql)
	skynet.ret(skynet.pack(result))
end

command[cmd.SQL_UPDATE_GAMETIME] = function(msg)
	local sql = string.format("update dt_member_game%d set gametime = %d where uid = %d", msg.uid%100, msg.gametime, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_UPDATE_REDPACKETTIME] = function(msg)
	local sql = string.format("update dt_member_game%d set redpackettime = %d where uid = %d", msg.uid%100, msg.redpackettime, msg.uid)
	db[serverconf.DB_ID.dt_member]:exec(sql)
end

command[cmd.SQL_FIRST_BUYER] = function(fid)
	local sql = string.format("select uid from dt_member_recharge where uid = %d and paystatus = 1 and responsestatus = 3", fid)
	local result = db[serverconf.DB_ID.dt_common]:query(sql)
	skynet.ret(skynet.pack(result))
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local type, msg = body[1], body[2]
		local f = command[type]
		if f then
			f(msg)
		else
			print("unknow sql msg", type)
		end
	end)
	skynet.register(types.server_name["mysql"])
--	test()
	Init()
end)
