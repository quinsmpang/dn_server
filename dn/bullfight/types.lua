local types = {
	GAME_TYPE_NOMAL					= 0,
	GAME_TYPE_CHANGE_THREE			= 1,
	GAME_TYPE_THREE_MORE			= 2,
	GAME_TYPE_FIVE_PLAYER			= 3,
	GAME_TYPE_BANKER				= 4,	
	GAME_TYPE_BULLFIGHT				= 11,

	PT_ERROR						= 0, 
	PT_SINGLE 						= 1, 
	PT_PAIR 						= 2,
	PT_DOUBLE_PAIR					= 3,
	PT_THREE 						= 4,
	PT_STRAIGHT 					= 5,
	PT_FLUSH 						= 6,
	PT_FULL_HOUSE					= 7,
	PT_FOUR 						= 8,
	PT_STRAIGHT_FLUSH				= 9,
	PT_FIVE 						= 10,

	COMPARE_SUIT					= false,

	FIRST_PT_THREE			= 2,
	SEC_PT_FULL_HOUSE		= 1,
	SEC_PT_FOUR				= 6,
	SEC_PT_STRAIGHT_FLUSH	= 8,
	SEC_PT_FIVE				= 10,
	THIRD_PT_FOUR			= 3,
	THIRD_PT_STRAIGHT_FLUSH	= 4,
	THIRD_PT_FIVE			= 5,

	PT_SP_NUNE					= 0,
	PT_SP_THREE_FLUSH			= 1,
	PT_SP_THREE_STRAIGHT		= 2,
	PT_SP_SIX_PAIRS				= 3,
	PT_SP_FIVE_PAIR_AND_THREE	= 4,
	PT_SP_FOUR_THREE_OF_A_KIND	= 5,
	PT_SP_SAME_SUIT				= 6,
	PT_SP_ALL_SMALL				= 7,
	PT_SP_ALL_BIG				= 8,
	PT_SP_THREE_FOUR_OF_A_KIND	= 9,
	PT_SP_THREE_STRAIGHT_FLUSH	= 10,
	PT_SP_ALL_KING				= 11,
	PT_SP_TWO_FIVE_AND_THREE	= 12,
	PT_SP_STRAIGHT				= 13,
	PT_SP_STRAIGHT_FLUSH		= 14,

	SP_TYPE_ADD = {
		[0] = 0,
		[1]	= 3,
		[2] = 4,
		[3] = 4,
		[4] = 5,
		[5] = 6,
		[6] = 10,
		[7] = 10,
		[8] = 10,
		[9] = 20,
		[10] = 20,
		[11] = 24,
		[12] = 30,
		[13] = 36,
		[14] = 108
	},
	SAFE_BOX_MAX_MONEY = {
		[0] = 0,
		[1] = 1000000,
		[2] = 6000000,
		[3] = 40000000,
		[4] = 1000000000
	},
	wshing_well = {
		[1] = {0, 0, 0, 0, 0.005, 0.02, 0.005, 0.005, 0.005, 0.02, 0.02, 0.05, 0.005, 0.05},
		[2] = {0, 0, 0, 0, 0.01, 0.1, 0.01, 0.01, 0.01, 0.1, 0.1, 0.3, 0.01, 0.3},
		[3] = {0, 0, 0, 0, 0.02, 0.2, 0.02, 0.02, 0.02, 0.2, 0.2, 0.5, 0.02, 0.5}
	},
	server_name = {
		["room"]	= "CPRoom",
		["game"]	= {
			[0] = "CPGame",
			[1] = "CPGame",
			[2] = "CPGame",
			[3] = "CPGame",
			[4] = "CPGame",
			[5] = "DiceGame",
			[11] = "BFGame"
			},
		["mysql"]	= "mysql",
		["redis"]	= "myredis",
		["center"]	= "CPCenter",
		["log"]		= "CPLog",
		["shop"]	= "Shop",
		["watchdog"]= {
			["S"] = "watchdog_short",
			["W"] = "watchdog_html",
			["A"] = "watchdog_admin"
			}
	},

	PT_NO_BULL			= 0,
	PT_BULL_ONE			= 1,
	PT_BULL_TWO			= 2,
	PT_BULL_THREE		= 3,
	PT_BULL_FOUR		= 4,
	PT_BULL_FIVE		= 5,
	PT_BULL_SIX			= 6,
	PT_BULL_SEVEN		= 7,
	PT_BULL_EIGHT		= 8,
	PT_BULL_NINE		= 9,
	PT_BULL_BULL		= 10,
	PT_SILVE_BULL		= 11,
	PT_GOLD_BULL		= 12,
	PT_BOMB				= 13,
	PT_ALL_SMALL_BULL	= 14,

	bulladd = {
		[0]		= 1,
		[1]		= 1,
		[2]		= 1,
		[3]		= 1,
		[4]		= 1,
		[5]		= 1,
		[6]		= 1,
		[7]		= 2,
		[8]		= 2,
		[9]		= 2,
		[10]	= 3,
		[11]	= 4,
		[12]	= 5,
		[13]	= 6,
		[14]	= 10
	},
	upling = {[1] = 1, [2] = 3, [3] = 5, [4] = 7, [5] = 10}

}

return types
