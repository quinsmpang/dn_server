local cmd = require "cmd"
require "gameprotobuf"
local protobuf = protobuf
local GP = protobuf.proto.game.package

local pack_msg = {
	[cmd.SMSG_LOGIN_SUCC]		= ".SMSG_LOGIN_SUCC roomid money vip ldays score winnum losenum drawnum mwin mlose mdraw title loginreward vipreward toolreward task_new firstlogin qq_vip dtmoney firstbuy",
	[cmd.SMSG_LOGIN_FAILD]		= ".SMSG_LOGIN_FAILD errcode",
	[cmd.SMSG_LOGOUT_SUCC]		= ".SMSG_LOGOUT_SUCC",
	[cmd.SMSG_SOMEONE_ENTER]	= ".SMSG_SOMEONE_ENTER uid info",
	[cmd.SMSG_ENTER_ROOM_SUCC]	= ".SMSG_ENTER_ROOM_SUCC roomid",
	[cmd.SMSG_ENTER_ROOM_FAILD] = ".SMSG_ENTER_ROOM_FAILD errcode",
	[cmd.SMSG_SOMEONE_SIT]		= ".SMSG_SOMEONE_SIT seaters",
	[cmd.SMSG_SIT_FAILD]		= ".SMSG_SIT_FAILD errcode",
	[cmd.SMSG_SOMEONE_STAND]	= ".SMSG_SOMEONE_STAND uid seatid",
	[cmd.SMSG_STAND_FAILD]		= ".SMSG_STAND_FAILD errcode",
	[cmd.SMSG_SOMEONE_QUIT]		= ".SMSG_SOMEONE_QUIT uid",
	[cmd.SMSG_QUIT_FAILD]		= ".SMSG_QUIT_FAILD errcode",
	[cmd.SMSG_DEAL_POKER]		= ".SMSG_DEAL_POKER cards sptype",
	[cmd.SMSG_CHANGE_POKER]		= ".SMSG_CHANGE_POKER time",
	[cmd.SMSG_CHOICE_POKER]		= ".SMSG_CHOICE_POKER sptype",
	[cmd.SMSG_COMPARE_POKER]	= ".SMSG_COMPARE_POKER playerconfs compareconfs shoot shootallid",
	[cmd.SMSG_SHOW_RESULT]		= ".SMSG_SHOW_RESULT results",
	[cmd.SMSG_FORCE_QUIT_GAME]	= ".SMSG_FORCE_QUIT_GAME uid losemoney",
	[cmd.SMSG_RESUME_GAME]		= ".SMSG_RESUME_GAME users cards lefttime selfsptype",
	[cmd.SMSG_TAKE_FEE]			= ".SMSG_TAKE_FEE uids money bankerfee",
	[cmd.SMSG_GAME_OVER]		= ".SMSG_GAME_OVER",
	[cmd.SMSG_GAME_OVER_AHEAD]	= ".SMSG_GAME_OVER_AHEAD",
	[cmd.SMSG_SOMEONE_CHANGE]	= ".SMSG_SOMEONE_CHANGE succ uid num",
	[cmd.SMSG_SOMEONE_CHOICE]	= ".SMSG_SOMEONE_CHOICE uid errcode",
	[cmd.SMSG_SOMEONE_CHOICE_SP]= ".SMSG_SOMEONE_CHOICE_SP uid errcode",
	[cmd.SMSG_CHANGE_RETURN]	= ".SMSG_CHANGE_RETURN shulff cards",
	[cmd.SMSG_NO_MONEY_KICK]	= ".SMSG_NO_MONEY_KICK errcode",
	[cmd.SMSG_UPDATE_ROOMCONF]	= ".SMSG_UPDATE_ROOMCONF basebet minmoney choicetime",
--	[cmd.SMSG_FAST_ENTER_RESP]	= ".SMSG_FAST_ENTER_RESP",
	[cmd.SMSG_ROOM_CHAT]		= ".SMSG_ROOM_CHAT uid msg",
	[cmd.SMSG_CHAT_TO]			= ".SMSG_CHAT_TO uid msg",
	[cmd.SMSG_UPDATE_FRIEND_STATE] = ".SMSG_UPDATE_FRIEND_STATE friends",
	[cmd.SMSG_BROADCAST]		= ".SMSG_BROADCAST num msg",
	[cmd.SMSG_ADD_MONEY]		= ".SMSG_ADD_MONEY uid addid money protectnum",
	[cmd.SMSG_FACE]				= ".SMSG_FACE uid faceid cost",
	[cmd.SMSG_TIMEOUT_KICK]		= ".SMSG_TIMEOUT_KICK",
	[cmd.SMSG_SERVER_CLOSE]		= ".SMSG_SERVER_CLOSE",
	[cmd.SMSG_PLAY_ONE_MATCH]	= ".SMSG_PLAY_ONE_MATCH sign",
	[cmd.SMSG_ADD_FRIEND]		= ".SMSG_ADD_FRIEND fid",
	[cmd.SMSG_DEL_FRIEND]		= ".SMSG_DEL_FRIEND fid",
	[cmd.SMSG_CREAT_SAFE_BOX]	= ".SMSG_CREAT_SAFE_BOX succ",
	[cmd.SMSG_LOGIN_SAFE_BOX]	= ".SMSG_LOGIN_SAFE_BOX succ money errcode",
	[cmd.SMSG_COIN_SAFE_BOX]	= ".SMSG_COIN_SAFE_BOX succ",
	[cmd.SMSG_SAFE_BOX_PWD]		= ".SMSG_SAFE_BOX_PWD succ pwd",
	[cmd.SMSG_SAFE_BOX_CHANGE_PWD] = ".SMSG_SAFE_BOX_CHANGE_PWD succ",
	[cmd.SMSG_SB_CHANGE_QUESTION] = ".SMSG_SB_CHANGE_QUESTION succ",
	[cmd.SMSG_PLAYER_GAMEINFO]	= ".SMSG_PLAYER_GAMEINFO uid money vip score winnum losenum drawnum mwinnum mlosenum mdrawnum title puid besttype",
--	[cmd.SMSG_PLAYER_GAMEINFO]	= ".SMSG_PLAYER_GAMEINFO uid money vip score winnum losenum drawnum mwinnum mlosenum mdrawnum title puid",
	[cmd.SMSG_FREE_FACE_CONF]	= ".SMSG_FREE_FACE_CONF endtime",
	[cmd.SMSG_SELF_TOOLS_CONF]	= ".SMSG_SELF_TOOLS_CONF tools",
	[cmd.SMSG_TASK_NEW_PLAYER]	= ".SMSG_TASK_NEW_PLAYER succ money",
	[cmd.SMSG_GOODS_DESCRIBE]	= ".SMSG_GOODS_DESCRIBE goods",
	[cmd.SMSG_UPDATE_NOTICE]	= ".SMSG_UPDATE_NOTICE notices",
	[cmd.SMSG_SHOP]				= ".SMSG_SHOP uid fid goodsid num addmoney score vip cowprice",
	[cmd.SMSG_USE_TOOL]			= ".SMSG_USE_TOOL uid succ toolid addmoney addscore vip",
	[cmd.SMSG_SELF_BOX]			= ".SMSG_SELF_BOX state",
	[cmd.SMSG_ADMIN_BROADCAST]	= ".SMSG_ADMIN_BROADCAST num msg",
	[cmd.SMSG_SEND_TASK_REWARD] = ".SMSG_SEND_TASK_REWARD uid succ taskid money",
	[cmd.SMSG_TASKCONF]			= ".SMSG_TASKCONF daywin dayplay tasks",
	[cmd.SMSG_A_NEW_DAY]		= ".SMSG_A_NEW_DAY",
	[cmd.SMSG_SHUT_DOWN]		= ".SMSG_SHUT_DOWN",
	[cmd.SMSG_TOP_LIST]			= ".SMSG_TOP_LIST topid players_info",
	[cmd.SMSG_HONOR_LIST]		= ".SMSG_HONOR_LIST weeksort dayhonor weekhonor day week",
--	[cmd.SMSG_START_BET]		= ".SMSG_START_BET",
	[cmd.SMSG_TABLE_GETALL]		= ".SMSG_TABLE_GETALL type tables",
	[cmd.SMSG_GRAB_BANKER]		= ".SMSG_GRAB_BANKER time type",
	[cmd.SMSG_NOTIFY_THE_BANKER]= ".SMSG_NOTIFY_THE_BANKER uid type",
	[cmd.SMSG_SOME_ONE_BET]		= ".SMSG_SOME_ONE_BET uid money errcode",
	[cmd.SMSG_BF_SHOW_RESULT]	= ".SMSG_BF_SHOW_RESULT results",
	[cmd.SMSG_BF_RESUME_GAME]	= ".SMSG_BF_RESUME_GAME states lefttime banker",
	[cmd.SMSG_SOME_ONE_GRAB_BANKER] = ".SMSG_SOME_ONE_GRAB_BANKER uid sign",
	[cmd.SMSG_BF_SOME_ONE_CHOICE]	= ".SMSG_BF_SOME_ONE_CHOICE uid succ cardstype cards",
	[cmd.SMSG_BF_GAME_START]	= ".SMSG_BF_GAME_START players uids",
	[cmd.SMSG_NOTIFY_BET]		= ".SMSG_NOTIFY_BET time",
	[cmd.SMSG_UP_GAME_DATA]		= ".SMSG_UP_GAME_DATA uid money score vip",
	[cmd.SMSG_SEND_DTMONEY]		= ".SMSG_SEND_DTMONEY uid addid dtmoney",
	[cmd.SMSG_GET_LAST_LIST]	= ".SMSG_GET_LAST_LIST onetime lastinfo",
	[cmd.SMSG_DEMAND_MONEY_WINDOW] = ".SMSG_DEMAND_MONEY_WINDOW num",
	[cmd.SMSG_CHOICE_FRIEND_DEMAND] = ".SMSG_CHOICE_FRIEND_DEMAND sourceid",
	[cmd.SMSG_REPLY_DEMAND_MONEY] = ".SMSG_REPLY_DEMAND_MONEY num fromName toName",
	[cmd.SMSG_HEART_BEAT]		= ".SMSG_HEART_BEAT",
	[cmd.SMSG_OVER_LOSE_LIMIT]	= ".SMSG_OVER_LOSE_LIMIT errcode",
	[cmd.SMSG_GET_ONLINE]		= ".SMSG_GET_ONLINE infos",
	[cmd.SMSG_GET_ONLINEINFO]	= ".SMSG_GET_ONLINEINFO roomid money score",
	[cmd.SMSG_SCRATCH_TIME]		= ".SMSG_SCRATCH_TIME time",
	[cmd.SMSG_SCRATCH_SEND_REWARD] = ".SMSG_SCRATCH_SEND_REWARD uid kind money dtmoney",
	[cmd.SMSG_RED_PACKET]		= ".SMSG_RED_PACKET time",
	[cmd.SMSG_GET_REDPACKET_REWARD] = ".SMSG_GET_REDPACKET_REWARD uid kind money",
}

local upack_msg = {
	[cmd.CMSG_LOGIN]			= ".CMSG_LOGIN uid key info",
	[cmd.CMSG_LOGIN_OUT]		= ".CMSG_LOGIN_OUT",
	[cmd.CMSG_ENTER_ROOM]		= ".CMSG_ENTER_ROOM roomid",
	[cmd.CMSG_QUIT_ROOM]		= ".CMSG_QUIT_ROOM",
	[cmd.CMSG_TRY_QUIT]			= ".CMSG_TRY_QUIT",
	[cmd.CMSG_SIT]				= ".CMSG_SIT seatid",
	[cmd.CMSG_STAND]			= ".CMSG_STAND",
	[cmd.CMSG_TRY_STAND]		= ".CMSG_TRY_STAND",
	[cmd.CMSG_FAST_ENTER]		= ".CMSG_FAST_ENTER roomtype gametype",
	[cmd.CMSG_FAST_SIT]			= ".CMSG_FAST_SIT",
	[cmd.CMSG_CHANGE_POKER]		= ".CMSG_CHANGE_POKER cards",
	[cmd.CMSG_CHOICE_POKER]		= ".CMSG_CHOICE_POKER thirdtype sectype firsttype cards",
	[cmd.CMSG_CHOICE_SP_TYPE]	= ".CMSG_CHOICE_SP_TYPE",
	[cmd.CMSG_CHAT_TO]			= ".CMSG_CHAT_TO id msg",
	[cmd.CMSG_BROADCAST]		= ".CMSG_BROADCAST toolid msg",
	[cmd.CMSG_ROOM_CHAT]		= ".CMSG_ROOM_CHAT msg",
	[cmd.CMSG_CHANGE_ROOM]		= ".CMSG_CHANGE_ROOM",
	[cmd.CMSG_UPDATE_FRIEND]	= ".CMSG_UPDATE_FRIEND uids",
	[cmd.CMSG_FACE]				= ".CMSG_FACE faceid",
	[cmd.CMSG_ADD_FRIEND]		= ".CMSG_ADD_FRIEND fid",
	[cmd.CMSG_DEL_FRIEND]		= ".CMSG_DEL_FRIEND fid",
	[cmd.CMSG_CREAT_SAFE_BOX]	= ".CMSG_CREAT_SAFE_BOX pwd question answer",
	[cmd.CMSG_LOGIN_SAFE_BOX]	= ".CMSG_LOGIN_SAFE_BOX pwd",
	[cmd.CMSG_COIN_SAFE_BOX]	= ".CMSG_COIN_SAFE_BOX type money",
	[cmd.CMSG_GET_PWD]			= ".CMSG_GET_PWD question answer",
	[cmd.CMSG_SAFE_BOX_CHANGE_PWD] = ".CMSG_SAFE_BOX_CHANGE_PWD newpwd oldpwd",
	[cmd.CMSG_SB_CHANGE_QUESTION] = ".CMSG_SB_CHANGE_QUESTION question answer newquestion newanswer",
	[cmd.CMSG_GET_PLAYER_GAMEINFO] = ".CMSG_GET_PLAYER_GAMEINFO uid",
	[cmd.CMSG_FREE_FACE_CONF]	= ".CMSG_FREE_FACE_CONF",
	[cmd.CMSG_SELF_TOOLS_CONF]	= ".CMSG_SELF_TOOLS_CONF",
	[cmd.CMSG_TASK_NEW_PLAYER]	= ".CMSG_TASK_NEW_PLAYER",
	[cmd.CMSG_SYSTEM_ERROR]		= ".CMSG_SYSTEM_ERROR errors env",
	[cmd.CMSG_GOODS_DESCRIBE]	= ".CMSG_GOODS_DESCRIBE",
	[cmd.CMSG_USE_TOOL]			= ".CMSG_USE_TOOL toolid",
	[cmd.CMSG_GET_SAFE_BOX]		= ".CMSG_GET_SAFE_BOX",
	[cmd.CMSG_GET_TASK_REWARD]	= ".CMSG_GET_TASK_REWARD taskid",
	[cmd.CMSG_HEART_BEAT]		= ".CMSG_HEART_BEAT",
	[cmd.CMSG_GET_TOP_LIST]		= ".CMSG_GET_TOP_LIST topid",
	[cmd.CMSG_GET_HONOR_LIST]	= ".CMSG_GET_HONOR_LIST",
--	[cmd.CMSG_BAKER_ENTER]		= ".",
	[cmd.CMSG_BET]				= ".CMSG_BET betmoney",
	[cmd.CMSG_TABLE_GETALL]		= ".CMSG_TABLE_GETALL type",
	[cmd.CMSG_BF_POKER_TYPE]	= ".CMSG_BF_POKER_TYPE pokertype cards",
	[cmd.CMSG_SOME_ONE_GRAB]	= ".CMSG_SOME_ONE_GRAB sign",
	[cmd.CMSG_EXCHANGE_MONEY]	= ".CMSG_EXCHANGE_MONEY goodsid platform count",
	[cmd.CMSG_GET_LAST_LIST]	= ".CMSG_GET_LAST_LIST",
	[cmd.CMSG_CHOICE_FRIEND_DEMAND] = ".CMSG_CHOICE_FRIEND_DEMAND fids",
	[cmd.CMSG_REPLY_DEMAND_MONEY] = ".CMSG_REPLY_DEMAND_MONEY num uid fromName toName",
	[cmd.CMSG_GET_FRIEND_MONEY_SUCC] = ".CMSG_GET_FRIEND_MONEY_SUCC",
	[cmd.CMSG_GET_ONLINE]		= ".CMSG_GET_ONLINE",
	[cmd.CMSG_GET_ONLINEINFO]	= ".CMSG_GET_ONLINEINFO uid",
	[cmd.CMSG_GET_SCRATCH_REWARD] = ".CMSG_GET_SCRATCH_REWARD",
	[cmd.CMSG_GET_REDPACKET_REWARD] = ".CMSG_GET_REDPACKET_REWARD",
}

local interface_layer = {
	["packet"]			= ".Packet type body",
	["card"]			= ".card point suit",
	["playerconf"]		= ".playerconf uid cards thirdtype sectype firsttype sptype",
	["compareconf"]		= ".compareconf uid firstadd secadd thirdadd totaladd",
	["shootconf"]		= ".shootconf shooter shooted",
	["result"]			= ".result uid nomaladd spadd winmoney cards",
	["users_state"]		= ".users_state uid state changenum sptype",
	["table"]			= ".table tid tplayer",
	["friend_state"]	= ".friend_state uid login roomid",
	["tool"]			= ".tool id typeid endtime num",
	["goods_describe"]	= ".goods_describe id describe type img title price statue addmoney",
	["notice"]			= ".notice id name sdate edate type content adminid",
	["task"]			= ".task taskid complete curstate money cow playpoint rtype dayplaynum",
	["player_info"]		= ".player_info uid money score info qq_vip vip",
	["player_info_honor"] = ".player_info_honor info honor",
	["player_info_last"] = ".player_info_last info",
	["bet"]				= ".bet uid bettype money",
	["dice_win_type"]	= ".dice_win_type type money",
	["dice_player_win"]	= ".dice_player_win uid wininfo totalwin",
	["bf_result"]		= ".bf_result uid totaladd winmoney pokertype cards",
	["bf_users_state"]	= ".bf_users_state uid state pokertype cards grabsign betmoney",
	["seater"]			= ".seater uid seatid",
	["online_info"]		= ".online_info uid name head sex"
}

local gamepacket = {}
gamepacket.pack = function(msgtype, ...)
	if pack_msg[msgtype] then
		local body = protobuf.pack(GP..pack_msg[msgtype], ...)
		return protobuf.pack(GP..".Packet type body", msgtype, body)
	elseif interface_layer[msgtype] then 
		return protobuf.pack(GP..interface_layer[msgtype], ...)
	else
		print("no this pack msgtype", msgtype)
		return nil
	end
end

gamepacket.upack = function(msgtype, ...)
	if upack_msg[msgtype] then
		local a = protobuf.unpack(GP..upack_msg[msgtype], ...)
		return protobuf.unpack(GP..upack_msg[msgtype], ...)
	elseif interface_layer[msgtype] then 
		local b = protobuf.unpack(GP..interface_layer[msgtype], ...)
		return protobuf.unpack(GP..interface_layer[msgtype], ...)
	else
		print("no this unpack msgtype", msgtype)
		return nil
	end
end

return gamepacket

