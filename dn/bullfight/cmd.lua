
CMD = {
	CMSG_LOGIN 						= 1001,
	CMSG_LOGIN_OUT					= 1002,
	CMSG_ENTER_ROOM					= 1003,
	CMSG_QUIT_ROOM					= 1004,
	CMSG_TRY_QUIT					= 1005,
	CMSG_SIT						= 1006,
	CMSG_STAND						= 1007,
	CMSG_TRY_STAND					= 1008,
	CMSG_FAST_ENTER					= 1009,
	CMSG_FAST_SIT					= 1010,
	CMSG_CHANGE_POKER				= 1011,
	CMSG_CHOICE_POKER				= 1012,
	CMSG_CHOICE_SP_TYPE				= 1013,
	CMSG_CHAT_TO					= 1014,
	CMSG_BROADCAST					= 1015,
	CMSG_ROOM_CHAT					= 1016,
	CMSG_CHANGE_ROOM				= 1017,
	CMSG_UPDATE_FRIEND				= 1018,
	CMSG_FACE						= 1019,
	CMSG_ADD_FRIEND					= 1020,
	CMSG_DEL_FRIEND					= 1021,
	CMSG_CREAT_SAFE_BOX				= 1022,
	CMSG_LOGIN_SAFE_BOX				= 1023,
	CMSG_COIN_SAFE_BOX				= 1024,
	CMSG_GET_PWD					= 1025,
	CMSG_SAFE_BOX_CHANGE_PWD		= 1026,
	CMSG_SB_CHANGE_QUESTION			= 1027,
	CMSG_GET_PLAYER_GAMEINFO		= 1028,
	CMSG_FREE_FACE_CONF				= 1029,
	CMSG_SELF_TOOLS_CONF			= 1030,
	CMSG_TASK_NEW_PLAYER			= 1031,
	CMSG_SYSTEM_ERROR				= 1032,
	CMSG_GOODS_DESCRIBE				= 1033,
	CMSG_USE_TOOL					= 1034,
	CMSG_GET_SAFE_BOX				= 1035,
	CMSG_GET_TASK_REWARD			= 1036,
	CMSG_HEART_BEAT					= 1037,
	CMSG_GET_TOP_LIST				= 1038,
	CMSG_BET_WISHING_WELL			= 1039,
	CMSG_UPDATE_WISHING_WELL		= 1040,
	CMSG_WISHING_WIN_LIST			= 1041,
	CMSG_EXCHANGE_MONEY				= 1042,
	CMSG_GET_HONOR_LIST				= 1043,
	CMSG_GET_LAST_LIST				= 1044,
	CMSG_CHOICE_FRIEND_WINDOW		= 1045,
	CMSG_CHOICE_FRIEND_DEMAND		= 1046,
	CMSG_REPLY_DEMAND_MONEY			= 1047,
	CMSG_GET_FRIEND_MONEY_SUCC		= 1048,
	CMSG_GET_ONLINE					= 1049,
	CMSG_GET_ONLINEINFO				= 1050,
	CMSG_GET_SCRATCH_REWARD			= 1051,
	CMSG_GET_REDPACKET_REWARD		= 1052,

	CMSG_BET						= 1101,
	CMSG_BF_POKER_TYPE				= 1102,
	CMSG_SOME_ONE_GRAB				= 1103,


	SMSG_LOGIN_SUCC		 			= 2002,
	SMSG_LOGIN_FAILD 				= 2003,
	SMSG_LOGOUT_SUCC				= 2004,
	SMSG_SOMEONE_ENTER				= 2005,
	SMSG_ENTER_ROOM_SUCC			= 2006,
	SMSG_ENTER_ROOM_FAILD			= 2007,
	SMSG_SOMEONE_SIT				= 2008,
	SMSG_SIT_FAILD					= 2009,
	SMSG_SOMEONE_STAND				= 2010,
	SMSG_STAND_FAILD				= 2011,
	SMSG_SOMEONE_QUIT				= 2012,
	SMSG_QUIT_FAILD					= 2013,
	SMSG_DEAL_POKER					= 2014,
	SMSG_CHANGE_POKER				= 2015,
	SMSG_CHOICE_POKER				= 2016,
	SMSG_COMPARE_POKER				= 2017,
	SMSG_SHOW_RESULT				= 2018,
	SMSG_FORCE_QUIT_GAME			= 2019,
	SMSG_RESUME_GAME				= 2020,
	SMSG_TAKE_FEE					= 2021,
	SMSG_GAME_OVER					= 2022,
	SMSG_GAME_OVER_AHEAD			= 2023,
	SMSG_SOMEONE_CHANGE				= 2024,
	SMSG_SOMEONE_CHOICE				= 2025,
	SMSG_SOMEONE_CHOICE_SP			= 2026,
	SMSG_CHANGE_RETURN				= 2027,
--	SMSG_CHANGE_RESULT				= 2028,
	SMSG_NO_MONEY_KICK				= 2029,
	SMSG_UPDATE_ROOMCONF			= 2030,
	SMSG_FAST_ENTER_RESP			= 2031,
	SMSG_ROOM_CHAT					= 2032,
	SMSG_CHAT_TO					= 2033,
	SMSG_UPDATE_FRIEND_STATE		= 2034,
	SMSG_BROADCAST					= 2035,
	SMSG_ADD_MONEY					= 2036,
	SMSG_FACE						= 2037,
	SMSG_TIMEOUT_KICK				= 2038,
	SMSG_SERVER_CLOSE				= 2039,
	SMSG_PLAY_ONE_MATCH				= 2040,
	SMSG_ADD_FRIEND					= 2041,
	SMSG_DEL_FRIEND					= 2042,
	SMSG_CREAT_SAFE_BOX				= 2043,
	SMSG_LOGIN_SAFE_BOX				= 2044,
	SMSG_COIN_SAFE_BOX				= 2045,
	SMSG_SAFE_BOX_PWD				= 2046,
	SMSG_SAFE_BOX_CHANGE_PWD		= 2047,
	SMSG_SB_CHANGE_QUESTION			= 2048,
	SMSG_PLAYER_GAMEINFO			= 2049,	
	SMSG_FREE_FACE_CONF				= 2050,
	SMSG_SELF_TOOLS_CONF			= 2051,
	SMSG_TASK_NEW_PLAYER			= 2052,
	SMSG_GOODS_DESCRIBE				= 2053,
	SMSG_UPDATE_NOTICE				= 2054,
	SMSG_SHOP						= 2055,
	SMSG_USE_TOOL					= 2056,
	SMSG_SELF_BOX					= 2057,
	SMSG_ADMIN_BROADCAST			= 2058,
	SMSG_SEND_TASK_REWARD			= 2059,
	SMSG_TASKCONF					= 2060,
	SMSG_A_NEW_DAY					= 2061,
	SMSG_SHUT_DOWN					= 2062,
	SMSG_TOP_LIST					= 2063,
	SMSG_BET_WSHING_WELL			= 2064,
	SMSG_WISHING_REWARD				= 2065,
	SMSG_UPDATE_WISHING_WELL		= 2066,
	SMSG_WISHING_WIN_LIST			= 2067,
	SMSG_HONOR_LIST					= 2068,
	SMSG_GET_ONLINE					= 2069,
	SMSG_GET_ONLINEINFO				= 2070,
	SMSG_SCRATCH_TIME				= 2071,
	SMSG_SCRATCH_SEND_REWARD		= 2072,
	
	SMSG_GRAB_BANKER				= 2100,
	SMSG_SOME_ONE_GRAB_BANKER		= 2101,
	SMSG_NOTIFY_THE_BANKER			= 2102,
	SMSG_SOME_ONE_BET				= 2103,
	SMSG_BF_SOME_ONE_CHOICE			= 2104,
	SMSG_BF_SHOW_RESULT				= 2105,
	SMSG_BF_RESUME_GAME				= 2106,
	SMSG_BF_GAME_START				= 2107,
	SMSG_NOTIFY_BET					= 2108,
	SMSG_UP_GAME_DATA				= 2109,
	SMSG_SEND_DTMONEY				= 2110,
	SMSG_GET_LAST_LIST				= 2111,
	SMSG_DEMAND_MONEY_WINDOW		= 2112,
	SMSG_CHOICE_FRIEND_DEMAND		= 2114,
	SMSG_REPLY_DEMAND_MONEY			= 2115,
	SMSG_HEART_BEAT					= 2116,
	SMSG_OVER_LOSE_LIMIT			= 2117,
	SMSG_RED_PACKET					= 2118,
	SMSG_GET_REDPACKET_REWARD		= 2119,



	EVENT_SOMEONE_BET				= 2701,
	EVENT_SEND_WEEKREWARD			= 2702,
	EVENT_REPLY_DEMAND_MONEY		= 2703,
	EVENT_GET_PFID					= 2074,

	
	EVENT_LOSE_MONEY				= 3001,
	EVENT_ADD_MONEY					= 3002,
	EVENT_GET_ROOMCONF				= 3003,
	EVENT_SOME_ONE_ENTER			= 3004,
	EVENT_SOME_ONE_SIT				= 3005,
	EVENT_SOME_ONE_STAND			= 3006,
	EVENT_SOME_ONE_QUIT				= 3007,
	EVENT_KICK_FOR_GAME_OVER		= 3008,
	EVENT_PLAY_ONE_MATCH			= 3009,
	EVENT_TAKE_FEE					= 3010,
	EVENT_NOTIFY_LOSER_GET_RESULT	= 3011,
	EVENT_LOSER_GET_RESULT			= 3012,
	EVENT_UPDATE_GAMECONF			= 3013,
	EVENT_RELOGIN					= 3014,
	EVENT_LOGIN_OUT					= 3015,
	EVENT_LOGIN						= 3016,
	EVENT_REDIRECT					= 3017,
	EVENT_AGENT_CLOSE				= 3018,
	EVENT_CHAT						= 3019,
	EVENT_SHOP						= 3020,
	EVENT_ADMIN_ADD_MONEY			= 3021,
	EVENT_KICK						= 3022,
	EVENT_ADD_FRIEND				= 3023,
	EVENT_DEL_FRIEND				= 3024,
	EVENT_GET_PLAYER_GAMEINFO		= 3025,
	EVENT_SERVER_CLOSE				= 3026,
	EVENT_TOOLS_CONF				= 3027,	
	EVENT_ADMIN_CHANGE_SF_PWD		= 3028,
	EVENT_A_NEW_DAY					= 3029,
	EVENT_SHUT_DOWN					= 3030,
	EVENT_ROOM_BROADCAST			= 3031,
	EVENT_ROOM_EVENT				= 3032,	
	EVENT_SEND_TO					= 3033,
	EVENT_CHANGE_AGENT				= 3034,
	EVENT_LOCK						= 3035,
	EVENT_UNLOCK					= 3036,
	EVENT_BROADCAST					= 3037,
	EVENT_GET_COWPRICE				= 3038,
	EVENT_ADMIN_ADD_DTMONEY			= 3039,
	EVENT_ADD_MONEY_ANOTHER			= 3040,

	EVENT_GET_MONEY					= 3101,
	EVENT_PLAYER_MONEY				= 3102,
	EVENT_BANKER_ENTER				= 3103,
	EVENT_GET_BANKER_MONEY			= 3104,
	EVENT_BANKER_MONEY				= 3105,
	EVENT_UPDATE_UPLOSE				= 3106,

	CMSG_TABLE_GETALL				= 4001,
	SMSG_TABLE_GETALL				= 4002,

	SQL_GET_LOGIN_KEY				= 5001,
	SQL_GET_PLAYERCONF				= 5002,
	SQL_GET_ROOMCONF				= 5003,
	SQL_WIN_LOG						= 5004,
	SQL_TABLE_LOG					= 5005,
	SQL_BACK_LOG					= 5006,
	SQL_BREAK_PROTECT				= 5007,
	SQL_UPDATE_PLAYERCONF			= 5008,
	SQL_GET_FRIENDS					= 5009,
	SQL_GET_ALL_GOODS				= 5010,
	SQL_ADMIN_ADD_MONEY				= 5011,
	SQL_BACK_MONEY					= 5012,
	SQL_GET_BLOCKED_PLAYER			= 5013,
	SQL_ADD_FRIEND					= 5014,
	SQL_DEL_FRIEND					= 5015,
	SQL_UPDATE_SAFE_BOX				= 5016,
	SQL_GET_SAFE_BOX				= 5017,
	SQL_GET_TITLE					= 5018,
	SQL_GET_PLAYER_GAMEINFO			= 5019,
	SQL_GET_SELF_TOOLS				= 5020,
	SQL_GET_LOGIN_CONF				= 5021,
	SQL_TASK_NEW_PLAYER				= 5022,
	SQL_SYSTEM_ERROR				= 5023,
	SQL_UPDATE_LOGIN_CONF			= 5024,
	SQL_LOGIN_OUT					= 5025,
	SQL_SHOP						= 5026,
	SQL_UPDATE_TOOLS				= 5027,
	SQL_GET_ORDER					= 5028,	
	SQL_GET_NOTICE					= 5029,
	SQL_ADMIN_SEND_TOOL				= 5030,
	SQL_USE_TOOL					= 5031,
	SQL_BLOCKED_PLAYER				= 5032,
	SQL_ADMIN_CHANGE_SF_PWD			= 5033,
	SQL_UPDATE_NOTICE				= 5034,
	SQL_COMPLETE_TASK				= 5035,
	SQL_GET_TASKCONF				= 5036,
	SQL_WRITE_SYSTEM_EMAIL			= 5037,
	SQL_MONEY_LOG					= 5038,
	SQL_ON_LINE_LOG					= 5039,
	SQL_GET_PLAYNUM					= 5040,
	SQL_UPDATE_PLAYNUM				= 5041,
	SQL_UPDATE_COWDUNG				= 5042,
	SQL_GET_COWDUNG					= 5043,
	SQL_GET_PFID					= 5044,
	SQL_INSERT_EXCHANGE_INFO		= 5045,
	SQL_GET_PTYPENUM				= 5046,
	SQL_UPDATE_PTYPENUM				= 5047,
	SQL_DTMONEY_LOG					= 5048,
	SQL_ADMIN_ADD_DTMONEY			= 5049,
	SQL_FLUSH_WEEKHONOR				= 5050,
	SQL_FLUSH_DAYHONOR				= 5051,
	SQL_SEND_MONEY					= 5052,
	SQL_GET_MONEY_VALUE				= 5053,
	SQL_GET_ALL_GIRLS				= 5054,
	SQL_GET_ONLINE_INFO				= 5055,
	SQL_GET_ONLINE_GAMEINFO			= 5056,
	SQL_UPDATE_GAMETIME				= 5057,
	SQL_FIRST_BUYER					= 5058,
	SQL_UPDATE_ACTIVER				= 5059,
	SQL_UPDATE_REDPACKETTIME		= 5060,

	ERROR_LOG					= 5201,
	DEBUG_LOG					= 5202,
	DAY_LOG						= 5203,
	WARMING_LOG					= 5204,
	MONEY_LOG					= 5205,
	TABLE_LOG					= 5206,
	ADMIN_LOG					= 5207,
	LOGIN_LOG					= 5208,
	ON_LINE_LOG					= 5209,

	ADMIN_ADD_MONEY					= 5401,
	ADMIN_ADD_DTMONEY				= 5402,
	ADMIN_KICK_PLAYER				= 5403,
	ADMIN_SERVER_CLOSE				= 5405,
	ADMIN_SOMEONE_SHOP				= 5406,
	ADMIN_SEND_TOOL					= 5410,


	ADMIN_CHANGE_SF_PWD				= 5440,
	ADMIN_BLOCKED_PLAYER			= 5461,
	ADMIN_UPDATE_NOTICE				= 5480,
	ADMIN_BROADCAST					= 5490,
	ADMIN_UPDATE_ROOMCONF			= 5491,
	ADMIN_UPDATE_TOOLCONF			= 5492

}
return	CMD
