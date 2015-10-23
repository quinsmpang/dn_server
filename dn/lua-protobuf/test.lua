package.path = package.path..";../public/lib/?.lua;./?.lua"
package.cpath = "./?.so"
local protobuf = require "protobuf"
--local parser = require "parser"
require "mydebug"
local print_r = print_r

addr = io.open("addressbook.pb","rb")
buffer = addr:read "*a"
addr:close()

protobuf.register(buffer)
--print_r(protobuf.decode("google.protobuf.FileDescriptorSet", buffer))
--print_r(protobuf)
--parser.register("addressbook.proto")


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
print("000000000000000")
print_r(t)


