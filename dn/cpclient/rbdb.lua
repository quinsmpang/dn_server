local skynet = require "skynet"
local mysqllib = require "mysql_client"
local guinfostr = require "guinfostr"
local unpack = unpack
local command = {}
require"mydebug"

local rbdb = {}
local mysql

local DB_COMMON = "bullfight_common"
local DB_MEMBER = "bullfight_member"
local DB_MEMLOG = "bullfight_member_log"
local DB_RELATION = "bullfight_relation"
local DB_MISSION = "bullfight"

local DBCOUNT = 100

local function hash(uid)
	return uid%DBCOUNT	
end
        
--"avatar":"111212121211",
--"pfid":1,
--"sex":0,
--"puid":"220743842",
--"name":"flyten1121223",
--"tencentLv":0,
--"tencentYear":false,
--"homePage":"js://toFriendHome,220743842"
command.GET_USERINFO = function(uid)
	print("***Get userinfo***")
	local result = mysql.query("SELECT nickname, header, puid, status, sex, pfid, userfrom, platfrom FROM %s.dt_member_platform%d WHERE uid=%d", DB_MEMBER, hash(uid), uid)
	if result and result[1] then
		local str, res = {}, result[1]
--		print_r(res)
		str = { [1] = res[3],
				[2] = res[5],
				[3] = res[1],--"unknown",
				[4] = 0,
				[5] = res[2],
				[6] = "unknown",
				[7] = res[6]
			}
	--		print("str[1]", str[1], "res[3]", res[3])
			local infostr = guinfostr.GetUserinfoString(str)
			skynet.ret(skynet.pack(infostr))
		else
--			print("sql fail", mysql.erro())
			skynet.ret(skynet.pack(false))
	end
end

command.GET_ROOMINFO = function(roomid)
	print("***Get roominfo***", roomid)
	local result = mysql.query("SELECT tid, tbasebet, tseat, tminchip, tmaxchip FROM %s.table WHERE tid = %d", DB_MISSION, roomid)
	skynet.ret(skynet.pack(result))
end

command.ADD_MONEY_ROBOT = function(msg)
	print("***Add money to robot")
	local result = mysql.exec("update %s.dt_member_game%d set gamecurrency = gamecurrency + %d where uid = %d", DB_MEMBER, msg.uid%100, msg.money, msg.uid)
--	skynet.ret(skynet.pack(result))
	print("....................................................")
end

local start
rbdb.start = function(f)
		start = f
end

command.MONEY_LOG_ROBOT = function(param)
	print("***Log of add money to robot")
	local result = mysql.exec("insert delayed into %s.dt_member_gold set uid = %d, changegold = %d, curgold = %d, time = %d, typeid = %d, assistid = %d", DB_MEMLOG, param.uid, param.money, param.curmoney, os.time(), param.typeid, 0)
end

skynet.start(function()
	print("start rdBD!!!!!!")	
	mysql = mysqllib.create()
	local connected = mysql.connect("10.4.7.243", 3388, "dicephp", "dicephp")
	print("*****rbdb, connected is", connected)
	rbdb.mysql = mysql
	assert(connected)
	print("*****rbdb, connected is succ")
	skynet.dispatch("lua", function(session, address, ...)
		local cmd = ...	
		print("Receive db cmd:", ...)
		local f = command[cmd]
		if f then
			f(select(2, ...))
		else
			print("error cmd:", cmd)
		end
	end)
	skynet.register("rbDB")
	if start then
		start()
	end
end)
