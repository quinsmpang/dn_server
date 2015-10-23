local mylib = require"myclib.c"
local lib_fun = {}

lib_fun.md5 = function(msg)
	msg = tostring(msg)
	return mylib.md5(msg)
end

return lib_fun
