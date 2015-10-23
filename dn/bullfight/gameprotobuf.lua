require "protobuf"

protobuf.proto = {}
local addr = io.open("proto/game.pb", "rb")
local buffer = addr:read"*a"
addr:close()

protobuf.register(buffer)
protobuf.proto.game = protobuf.decode("google.protobuf.FileDescriptorSet", buffer).file[1]

--addr = io.open("proto/chinesepoker.pb", "rb")
--buffer = addr:read"*a"
--addr:close()
--protobuf.register(buffer)
--protobuf.proto.chinesepoker = protobuf.decode("google.protobuf.FileDescriptorSet", buffer).file[1]
