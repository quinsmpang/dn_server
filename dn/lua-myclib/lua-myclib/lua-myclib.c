#include "md5.h"
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <stdio.h>

static int _md5(lua_State *L)
{
	const char *msg = luaL_checkstring(L, 1);
	MD5_CTX ctx;
	unsigned int len = strlen(msg);
	unsigned char ret[16];
	MD5Init(&ctx);
	MD5Update(&ctx, msg, len);
	MD5Final(ret, &ctx);
	unsigned char ch[32];
	int i;
	for(i = 0; i < 16; i ++)
		sprintf(ch + i * 2, "%02x", ret[i]);
	lua_pushstring(L, ch);
	return 1;
}

int luaopen_myclib_c(lua_State* L)
{
	luaL_Reg mylib[] = {
		{"md5", _md5},
		{NULL, NULL},
	};
	luaL_checkversion(L);
	luaL_newlib(L, mylib);
	return 1;
}
