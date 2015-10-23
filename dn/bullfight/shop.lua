local skynet = require"skynet"
local table = table
local string = string
local pairs = pairs
local cmd = require"cmd"
local goods = {}
local goods_describe
local error = require"errorcode"
local serverconf = require "serverconf"
require "gameprotobuf"
local protobuf = protobuf
local GP = protobuf.proto.game.package 

local command = {}

local function InitGoodsDescribe()
	local result = skynet.call("mysql", "lua", cmd.SQL_GET_ALL_GOODS)
	if result and #result ~= 0 then
		local tools = {}
		for k, v in pairs(result) do
			local tool = {}
			tool.id = tonumber(result[k][1])
			tool.describe = result[k][2]
			tool.type = tonumber(result[k][3])
			tool.isshow = tonumber(result[k][4])
			tool.img = result[k][5]
			tool.title = result[k][6]
			tool.price = tonumber(result[k][7])
			tool.addmoney = tonumber(result[k][8])
			if tool.isshow ~= 0 then
		--		local t = protobuf.pack(GP..".goods_describe id describe type img title price",
		--			tool.id, tool.describe, tool.type, tool.img, tool.title, tool.price)
				local t = protobuf.pack(GP..".goods_describe id describe type img title price state addmoney",
					tool.id, tool.describe, tool.type, tool.img, tool.title, tool.price, tool.isshow, tool.addmoney)
				table.insert(tools, t)
			end
		end
		goods_describe = protobuf.pack(GP..".SMSG_GOODS_DESCRIBE goods", tools)
		goods_describe = protobuf.pack(GP..".Packet type body", cmd.SMSG_GOODS_DESCRIBE, goods_describe)
	else
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, "Get goods error")
		skynet.abort()
	end
end

--道具ID,道具类型,vip等级,使用天数,第一次送币数,每天多送,使用次数,活动送道具卡,一般搭售,游戏币价,大头币价,能否購買,加送
--local function InitGoodsConf()
--	local fd = io.open(serverconf.tools_file, "r")
--	if fd then
--		for line in fd:lines() do
--			local start = 1
--			local tool = {}
--			for i = 1, 7 do
--				local _, last, p = string.find(line, "(%d+)%|", start)
--				start = last
--				tool[i] = tonumber(p)
--			end
--			for i = 8, 9 do--待扩展
--				local _, last, p = string.find(line, "(%|)", start)
--				start = last
--			end
--			for i = 10, 13 do
--				local _, last, p = string.find(line, "(%d+)%|", start)
--				start = last
--				tool[i] = tonumber(p)
--			end
--			goods[tool[1]] = {
--				id = tool[1],
--				typeid = tool[2],
--				vip = tool[3],
--				udays = tool[4],
--				fmoney = tool[5],
--				dmoney = tool[6],
--				ucount = tool[7],
--				coin_price = tool[10]
--			}
--		end
--	else
--		skynet.send("CPLog", "lua", cmd.ERROR_LOG, "Init goods error")
--		skynet.abort()
--	end
--end

local function InitGoodsConf()
	local t = skynet.call("myredis", "lua", "get_tools_conf")
	if t then
		for k, v in pairs(t) do
			goods[v[1]] = {
				id = v[1],
				typeid = v[2],
				vip = v[3],
				udays = v[4],
				fmoney = v[5], --首次赠送金币
				dmoney = v[6], --每日登陆赠送金币
				ucount = v[7], --可使用的次数
				coin_price = v[8], --人民币单价
				cow_price = v[9] -- 牛粪单价
			}
			print("id = ", goods[v[1]].id, "typeid = ", goods[v[1]].typeid, "vip = ", goods[v[1]].vip, "udays = ", goods[v[1]].udays, 
			"fmoney =", goods[v[1]].fmoney, "    dmoney =", goods[v[1]].dmoney, "  ucount=", goods[v[1]].ucount, "  price = ", goods[v[1]].coin_price, "        cow_price =", goods[v[1]].cow_price)
		end
	else
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, "Init goods error")
		skynet.abort()
	end
end

command[cmd.EVENT_GET_COWPRICE] = function(body)
	local _, cowgoodsid = unpack(body)
	skynet.ret(skynet.pack(goods[cowgoodsid].cow_price))
end

command[cmd.EVENT_SHOP] = function(body)
	local _, conf = unpack(body)
	local succ = false
	local sendtool = nil
	if not goods[conf.goodsid] then
		local log = string.format("have no this goods, order id:%s", conf.order_nu)
		skynet.send("CPLog", "lua", cmd.ERROR_LOG, log)
	else
		local tool = goods[conf.goodsid]
		conf.todb = true
		conf.num = tool.ucount
		conf.lasttime = 0
		conf.stime = os.time()
		conf.status = 1
		conf.money = 0
		conf.freecard = 0
		conf.kind = tool.typeid
		if not conf.resean then
			conf.resean = tostring(0)
		end
		if tool.typeid == 1 or tool.typeid == 3 then--vip卡， 金币卡
			conf.money = (tool.fmoney + tool.dmoney) * conf.count
			if tool.dmoney == 0 then
				conf.todb = false
			end
			if tool.ucount ~= 0 then
				conf.num = tool.ucount - 1
			end
			if tool.typeid == 1 then
				conf.lasttime = tool.udays * 24*60*60
				conf.todb = true
				conf.num = 0
			end
		elseif tool.typeid == 2 then -- 积分清除卡
			conf.score = tool.fmoney
			conf.stime = 0
			conf.status = 0
		elseif tool.typeid == 4 then -- 喇叭卡
			conf.status = 0
		elseif tool.typeid == 5 then -- 多倍积分卡
			conf.lasttime = tool.udays *60*60
		end

		if conf.firstbuy == 0 and conf.goodsid == 7 then --第一次购买商场道具，额外奖励
			conf.money = conf.money + serverconf.firstbuy_tool
		end

		local res, insertid = skynet.call("mysql", "lua", cmd.SQL_SHOP, conf)
		if res then
			skynet.send("CPCenter", "lua", cmd.EVENT_SHOP, conf, insertid)
		end
		succ = res
	end
	skynet.ret(skynet.pack(succ))
	if conf.isshop and conf.kind ~= 1 then --赠送免费表情卡
		for k, v in pairs(goods) do
			if v.typeid == 6 then 
				sendtool = {
					goodsid = k,
					fid = 0,
					uid = conf.uid,
					count = conf.count,
					notice = 0,
					resean = tostring(0),
					todb = true,
					money = 0,
					status = 1,
					lasttime = v.udays*24*60*60,
					num = v.ucount,
					kind = v.typeid,
					stime = os.time()
				}
				break
			end
		end
		local res, insertid = skynet.call("mysql", "lua", cmd.SQL_SHOP, sendtool)
		if res then
			skynet.send("CPCenter", "lua", cmd.EVENT_SHOP, sendtool, insertid)
		end
	end
end

command[cmd.EVENT_TOOLS_CONF] = function(body)
	skynet.ret(skynet.pack(goods))
end

command[cmd.CMSG_GOODS_DESCRIBE] = function(body)
	skynet.ret(skynet.pack(goods_describe))
end

command[cmd.ADMIN_UPDATE_TOOLCONF] = function(body)
	InitGoodsDescribe()
	InitGoodsConf()
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, ...) 
		local body = {...}
		local mtype = body[1]
		body[1] = address
		local f = command[mtype]
		print("shop recv msg", mtype)
		if f then
			f(body)
		else
			print("unknow mtype", mtype)
		end
	end)
	skynet.register("Shop")
	InitGoodsDescribe()
	InitGoodsConf()
end)

