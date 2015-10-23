local mysqllib = require "mysql.c"
local string = string
local mysql = {}

mysql.create = function()
	local inst = mysqllib.create()
	local t = { inst = inst }
	t.connect = function(...)
		local n = select('#', ...)
		if n < 4 then
			local host = "localhost"
			local port = "/tmp/mysql.sock"
			return mysqllib.connect(t.inst, host, port, ...)
		else
			return mysqllib.connect(t.inst, ...)
		end
	end
	t.query = function(...)
		local r,p = mysqllib.query(t.inst, string.format(...))
		if not r then
			t.errmsg = p
		end
		return r
	end
	t.exec = function(...)
		local rows,param = mysqllib.exec(t.inst, string.format(...))
		if rows then
			t.id = param
		else
			t.errmsg = param
		end
		return rows
	end
	t.error = function()
		return t.errmsg or "success"
	end
	t.insertid = function()
		return t.id
	end
	t.close = function()
		mysqllib.close(t.inst)
		t = nil
	end
	return t
end

return mysql
