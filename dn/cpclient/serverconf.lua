local serverconf = {
--	TEST_MODEL			= true,
	TEST_MODEL			= false,
	DB_ID = {
		dt_common		= 1,
		dt_member		= 2,
		dt_member_log	= 3,
		dt_relation		= 4,
		member			= 5,
		count			= 6,
		log				= 7,
		task			= 8
	},
	DB_NAME = {
		[1] = "bullfight_common",
		[2] = "bullfight_member",
		[3] = "bullfight_member_log",
		[4] = "bullfight_relation",
		[5] = "bullfight",
		[6] = "thirteenpoker_count",
--		[7] = "thirteenpoker_log",
--		[8] = "thirteenpoker_medal"
	},

	DB_HOST		= "10.4.7.243",
--	DB_HOST		= "192.168.0.5",
	DB_PORT		= 3388,
	DB_USER		= "dicephp",

	DB_PASSWORD = "dicephp",

--	test_IP1	= "183.62.227.113",
--	test_IP1	= "122.226.207.15",
	test_IP1	= "10.4.7.243",
--	test_IP1	= "192.168.0.111",
	test_IP2	= "183.13.102.129",

	logfile		= "server.log",
	tools_file	= "tools.txt",
	lognum		= 10,
	logsize		= 10000000,
	ERROR_LOG	= true,
	DEBUG_LOG	= true,
	DAY_LOG		= true,
	WARMING_LOG = true,

	task_money = {
		newplayer = 100
	},
	login_reward = {
		[1] = 400,
		[2] = 500,
		[3] = 600,
		[4] = 700,
		[5] = 800,
		[6] = 900,
		[7] = 1000
	},

	face_cost	= 0.02, 
	language	= 2, --2:简体中文， 3：繁体中文， 4：英文

	money_log = {
		admin			= 201,
		new_player		= 202,
		ticket			= 203,
		table_win		= 204,
		face			= 205,
		escape			= 206,
		safe_box		= 207,
		login_reward	= 208,
		wshing_bet		= 209,
		wshing_reward	= 210,
		robot_addmoney	= 211
	},
	T_ON_LINE		= 12000, --写在线人数间隔

	admin_key = "aaaaaa"
}

return serverconf
