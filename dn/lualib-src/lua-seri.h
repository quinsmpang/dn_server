#ifndef LUA_SERIALIZE_H
#define LUA_SERIALIZE_H

#include <lua.h>

int _luaseri_pack(lua_State *L);
int _luaseri_unpack(lua_State *L);

char * _pack_args(lua_State *L, size_t index, size_t * sz);
int _unpack_args(lua_State *L, char *buffer, size_t sz);

#endif
