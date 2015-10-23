package.path = package.path..";../public/lib/?.lua;./?.lua"
package.cpath = "./?.so"
local protobuf = require "protobuf"
local parser = require "parser"
require "mydebug"
local print_r = print_r

--addr = io.open("addressbook.pb","rb")
--buffer = addr:read "*a"
--addr:close()
--
--protobuf.register(buffer)
--local t = parser.register("addressbook.proto")
local t=  parser.register({"cmd.proto", "commonService.proto"})
--local t=  parser.register({"i.proto"})

print("package----->", t[1].package)
print_r(t[1])

addressbook = {
	name = "Alice",
	id = 12345,
	phone = {
		{ number = "1301234567" },
		{ number = "87654321", type = "WORK" },
	}
}

code = protobuf.encode("tutorial.Person", addressbook)

decode = protobuf.decode("tutorial.Person" , code)

print(decode.name)
print(decode.id)
for _,v in ipairs(decode.phone) do
	print("\t"..v.number, v.type)
end

phonebuf = protobuf.pack("tutorial.Person.PhoneNumber number","87654321")
phonebuf2 = protobuf.pack("tutorial.Person.PhoneNumber number", "8127113")
phonebuf3 = protobuf.pack("tutorial.Person.PhoneNumber number", "8127111")
buffer = protobuf.pack("tutorial.Person name id phone test", "Alice", 123, { phonebuf, phonebuf2, phonebuf3 }, {1, 23, 3})
local t = {protobuf.unpack("tutorial.Person name id phone test", buffer)}
print_r(t)

