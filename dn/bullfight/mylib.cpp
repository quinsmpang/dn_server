static int l_dir(lua_State *L)
{
	...
}

static const struct luaL_reg mylib[] = 
{
	{},
	{NULL, NULL}
}

int luaopen_mylib(lua_State *L)
{
	luaL_openlib(L, "mylib", mylib, 0);
	return 1;
}
