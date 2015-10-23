.PHONY : all  clean

all : protobuf.so addressbook.pb

LIBSRCS = context.c varint.c array.c pattern.c register.c proto.c map.c alloc.c rmessage.c wmessage.c bootstrap.c stringpool.c decode.c

protobuf.so : pbc-lua.c $(LIBSRCS)
	gcc -O2 -g -Wall -fno-strict-aliasing --shared -fPIC -o $@ $^  

addressbook.pb : addressbook.proto
	protoc -o$@ $<

clean :
	rm -f protobuf.so addressbook.pb
