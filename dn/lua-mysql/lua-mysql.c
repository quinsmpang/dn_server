#include <mysql.h>
#include <stdlib.h>
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>

static int
_create(lua_State *L)
{
	MYSQL *mysql_inst;
	mysql_inst = mysql_init(NULL);
	mysql_options(mysql_inst, MYSQL_OPT_RECONNECT, "1");
	if(mysql_inst == NULL) {
		luaL_error(L, "Can't create mysql instance");
		return 0;
	}
	lua_pushlightuserdata(L, mysql_inst);
	return 1;
}

static int
_connect(lua_State *L)
{
	const char *host, *user, *passwd, *database = 0, *unixsocket = 0;
	int port = 0;
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	MYSQL *inst = lua_touserdata(L, 1);
	host = luaL_checkstring(L, 2);
	int type = lua_type(L, 3);
	switch (type) {
		case LUA_TSTRING:
			unixsocket = luaL_checkstring(L, 3);
			break;
		case LUA_TNUMBER:
			port = luaL_checkinteger(L, 3);
			break;
		default :
			luaL_error(L, "mysql.connect invalid param %s", lua_type(L, 4));
			return 0;
	}
	user = luaL_checkstring(L, 4);
	passwd = luaL_checkstring(L, 5);
	if (lua_gettop(L) > 5) {
		database = luaL_checkstring(L, 6);
	}
	MYSQL *mysql = mysql_real_connect(inst, host, user, passwd, database, port, unixsocket, CLIENT_MULTI_STATEMENTS);
	if(!mysql){
		luaL_error(L, "Could not connect to MySQL database at %s: %s", host, mysql_error(inst));
		return 0;
	}
	if (mysql_autocommit(inst, 1) != 0)
	{
		luaL_error(L, "mysql.connect AUTOCOMMIT NOT SET TO 1");
		return 0;
	}
	mysql_set_character_set(inst, "utf8");
	lua_pushboolean(L, 1);
	return 1;
}

static int
_close(lua_State* L)
{
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	MYSQL *inst = lua_touserdata(L, 1);
	if (inst) {
		mysql_close(inst);
	}
	return 0;
}

static int
make_query_result(lua_State * L, MYSQL *inst)
{
	MYSQL_RES *result = mysql_store_result(inst);
	if(result == NULL) {
		luaL_error(L, "mysql_store_result() fatal error: %s\n", mysql_error(inst));
		return 0;
	}
	int row_count = mysql_affected_rows(inst);
	int field_count = mysql_field_count(inst);
	MYSQL_ROW row;
	lua_createtable(L, row_count, 0);
	int ridx = 0;
	while ( (row = mysql_fetch_row(result)) != NULL ) {
		lua_pushinteger(L, ++ridx);
		lua_createtable(L, field_count, 0);
		int i;
		for (i = 0; i < field_count; i++) {
			lua_pushinteger(L, i+1);
			lua_pushstring(L, row[i]);
			lua_rawset(L, -3);
		}
		lua_rawset(L, -3);
	}
	mysql_free_result(result);
	return 1;
}

static int
make_exec_result(lua_State *L, MYSQL *inst)
{
	int affected_rows = mysql_affected_rows(inst);
	int inserted_id = mysql_insert_id(inst);
	lua_pushinteger(L, affected_rows);
	lua_pushinteger(L, inserted_id);
	return 2;
}

static int
_query(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	MYSQL *inst = lua_touserdata(L, 1);
	const char* sql = luaL_checkstring(L, 2);
	if (mysql_ping(inst) != 0) {
		luaL_error(L, "Mysql connection has gone away!");
		return 0;
	}
	if (mysql_query(inst, sql)) {
		/* luaL_error(L, "Query error:%s, SQL: '%s'\n", mysql_error(inst), sql); */
		lua_pushboolean(L, 0);
		lua_pushstring(L, mysql_error(inst));
		return 2;
	}
	return make_query_result(L, inst);
}

static int
_exec(lua_State *L)
{
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	MYSQL *inst = lua_touserdata(L, 1);
	const char *sql = luaL_checkstring(L, 2);
	if (mysql_ping(inst) != 0) {
		luaL_error(L, "Mysql connection has gone away!");
		return 0;
	}
	if (mysql_query(inst, sql)) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, mysql_error(inst));
		return 2;
	}
	return make_exec_result(L, inst);
}

int
luaopen_mysql_c(lua_State* L)
{
	luaL_Reg mysql[] = {
		{ "create", _create },
		{ "connect", _connect },
		{ "close", _close },
		{ "query", _query },
		{ "exec", _exec },
		{ NULL, NULL },
	};
	luaL_checkversion(L);
	luaL_newlib(L, mysql);
	return 1;
}

