local mysqllib = require "mysql.c"
local string = string
local mysql = {}
local command = {}

function command:connect(...)
	local n = select('#', ...)
	if n < 4 then
		local host = "localhost"
		local port = "/tmp/mysql.sock"
		return mysqllib.connect(self.__handle, host, port, ...)
	else
		return mysqllib.connect(self.__handle, ...)
	end
end

function command:query(...)
	local ret, p = mysqllib.query(self.__handle, string.format(...))
	if not ret then
		command.errmsg = p
		return ret
	end
--	local qresult = require"queryresult"
--	qresult:init(ret)
--	return qresult
	if p == 1 then
		return ret[1]
	else
		return ret
	end
end

function command:exec(...)
	local rows, param = mysqllib.exec(self.__handle, string.format(...))
	if rows then
		command.id = param
	else
		command.errmsg = param
	end
	return rows
end

function command:insertid()
	return command.id
end

function command:close()
	mysqllib.close(self.__handle)
	self.__handle = nil
end

local meta = {
	__index = command
}

function mysql.create()
	local handle = mysqllib.create()
	return setmetatable({__handle = handle, sql = handle }, meta)
end

return mysql
