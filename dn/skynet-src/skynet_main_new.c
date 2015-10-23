#include "skynet_imp.h"
#include "skynet_env.h"
#include "luacompat52.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <signal.h>
#include <unistd.h>
#include "alloc.c"

static int
optint(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		char tmp[20];
		sprintf(tmp,"%d",opt);
		skynet_setenv(key, tmp);
		return opt;
	}
	return strtol(str, NULL, 10);
}

/*
static int
optboolean(const char *key, int opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		skynet_setenv(key, opt ? "true" : "false");
		return opt;
	}
	return strcmp(str,"true")==0;
}
*/
static const char *
optstring(const char *key,const char * opt) {
	const char * str = skynet_getenv(key);
	if (str == NULL) {
		if (opt) {
			skynet_setenv(key, opt);
		}
		return opt;
	}
	return str;
}

static void
_set_env(lua_State *L) {
	lua_pushnil(L);  /* first key */
	while (lua_next(L, -2) != 0) {
		int keyt = lua_type(L, -2);
		if (keyt != LUA_TSTRING) {
			fprintf(stderr, "Invalid config table\n");
			exit(1);
		}
		const char * key = lua_tostring(L,-2);
		if (lua_type(L,-1) == LUA_TBOOLEAN) {
			int b = lua_toboolean(L,-1);
			skynet_setenv(key,b ? "true" : "false" );
		} else if (lua_type(L, -1) != LUA_TTABLE) {
			const char * value = lua_tostring(L,-1);
			if (value == NULL) {
				fprintf(stderr, "Invalid config table key = %s\n", key);
				exit(1);
			}
			skynet_setenv(key,value);
		}
		lua_pop(L,1);
	}
	lua_pop(L,1);
}

static int
_init_env(lua_State *L, const char *tag) {
	int find_tag = 0;
	lua_pushglobaltable(L);
	lua_pushnil(L);
	while(lua_next(L, -2) != 0) {
		if (lua_type(L, -2) != LUA_TSTRING) {
			fprintf(stderr, "Invalid config table\n");
			exit(1);
		}
		if (lua_type(L, -1) == LUA_TTABLE) {
			const char * key = lua_tostring(L, -2);
			if (strcmp(key, tag) == 0) {
				find_tag = 1;
				_set_env(L);
				break;
			}
		}
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
	return find_tag;
}

static int
daemon_init(int nochdir, int noclose)
{
    daemon(nochdir, noclose);
    signal(SIGHUP, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);
    return 0;
}

int
main(int argc, char *argv[]) {
	// argument index in argv[]
	int config_index = 2;
	int tag_index = 1;
	const char * config_file = "config";
	if (argc > 1 && strstr(argv[1], "config")) {
		config_index = 1;
		tag_index = 2;
	}
	if (argc > config_index) {
		config_file = argv[config_index];
	}
	skynet_env_init();

	struct skynet_config config;

	struct lua_State *L = luaL_newstate();
	luaL_openlibs(L);	// link lua lib
	/* lua_close(L); */

	/* L = luaL_newstate(); */

	int err = luaL_dofile(L, config_file);
	if (err) {
		fprintf(stderr,"%s\n",lua_tostring(L,-1));
		lua_close(L);
		return 1;
	}
	const char * tag = "main";
	if (argc > tag_index) {
		tag = argv[tag_index];
	}
	int ok = _init_env(L, tag);
	if (!ok) {
		fprintf(stderr, "No tag '%s' in config file '%s'\n", tag, config_file);
		return 1;
	}

	optint("argc", argc);
	int i;
	char key[8] = {"argv0"};
	for (i = 0; i < argc; i++) {
		if (i == config_index) {
			optstring("argv2", config_file);
		} else if (i == tag_index) {
			optstring("argv1", tag);
		} else {
			optstring(key, argv[i]);
		}
		key[4] += 1;
	}

	const char *path = optstring("lua_path","./lualib/?.lua;./lualib/?/init.lua");
	setenv("LUA_PATH",path,1);
	const char *cpath = optstring("lua_cpath","./luaclib/?.so");
	setenv("LUA_CPATH",cpath,1);
	optstring("luaservice","./service/?.lua");

	config.thread =  optint("thread",8);
	config.module_path = optstring("cpath","./service/?.so");
	config.logger = optstring("logger",NULL);
	config.harbor = optint("harbor", 1);
	config.master = optstring("master","127.0.0.1:2012");
	config.start = optstring("start","main.lua");
	config.local = optstring("address","127.0.0.1:2525");
	config.standalone = optstring("standalone",NULL);
	int runasdaemon = optint("runasdaemon", 0);

	lua_close(L);
	if (runasdaemon) {
		daemon_init(1, 1);
	}
	skynet_start(&config);

	printf("skynet exit\n");

	return 0;
}
