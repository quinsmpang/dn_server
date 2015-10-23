local skynet = require "skynet"

local cache = {}

local print = function(...)
	table.insert(cache, "\t"..table.concat({...}, " "))
end

local cmd = { ... }

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result,"\t")
end

local function dump_line(key, value)
	if type(value) == "table" then
		print(key, format_table(value))
	else
		print(key,tostring(value))
	end
end

local function dump_list(list)
	local index = {}
	for k in pairs(list) do
		table.insert(index, k)
	end
	table.sort(index)
	for _,v in ipairs(index) do
		dump_line(v, list[v])
	end
	skynet.send(".console", "lua", table.concat(cache, "\n"))
end

skynet.start(function()
	local list = skynet.call(".launcher","lua", unpack(cmd))
	if list then
		dump_list(list)
	end
	skynet.exit()
end)
