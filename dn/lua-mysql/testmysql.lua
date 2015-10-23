package.cpath = package.cpath..";../luaclib/?.so"
local mysql = require "mysql"


local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep

function print_r(root)
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	print(_dump(root, "",""))
end

local mysql, mysql2 = mysql.create(), mysql.create()
mysql.connect("root", "123456", "Dice")
local success =  mysql2.connect("localhost", 3306, "root", "123456")
if success then
	print("Connected to mysql")
end
local record = mysql.query("select money from dice_member where uid = 39")
print_r(record)
local res = mysql.exec("update dice_member set money = 1000000 where uid = 39")
if res then
	print("affected rows", res)
else
	print("error", mysql.error())
end

local record = mysql.query("asdf")
if not record then
	print("error", mysql.error())
end

print("------------------------")
print_r(mysql2.query("select Host,User,Password from mysql.user where User='dicephp'"))


mysql.close()
mysql2.close()

