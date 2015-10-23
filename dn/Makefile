.PHONY : all clean

# CFLAGS = -g -Wall
CFLAGS = -g -O2 -Wall -DTENCENT
ifeq ($(MAKECMDGOALS), websocket)
CFLAGS += -DWEBSOCKET
endif
LDFLAGS = -lpthread -llua -ldl -lm

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
ifeq ($(uname_S), Darwin)
	SHARED = -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
else
	DEPS += jemalloc/lib/libjemalloc.a
	CFLAGS += -DUSE_JEMALLOC -I./jemalloc/include
	LDFLAGS += -lrt -Wl,-E 
	SHARED = -fPIC --shared
endif

all : \
  skynet \
  skynet-new \
  service/snlua.so \
  service/logger.so \
  service/gate.so \
  service/client.so \
  service/connection.so \
  service/master.so \
  service/multicast.so \
  service/tunnel.so \
  service/harbor.so \
  service/localcast.so \
  luaclib/skynet.so \
  luaclib/socket.so \
  luaclib/int64.so \
  luaclib/mcast.so \
  luaclib/mysql.so \
  luaclib/protobuf.so \
  luaclib/myclib.so \
  client

websocket : all

JEMALLOC_CFLAGS= -std=gnu99 -Wall -pipe -g3 -O3 -funroll-loops
jemalloc/lib/libjemalloc.a :
	cd jemalloc && ./configure --with-jemalloc-prefix=je_ --enable-cc-silence CFLAGS="$(JEMALLOC_CFLAGS)"
	cd jemalloc && make

skynet : \
  skynet-src/skynet_main.c \
  skynet-src/skynet_handle.c \
  skynet-src/skynet_module.c \
  skynet-src/skynet_mq.c \
  skynet-src/skynet_server.c \
  skynet-src/skynet_start.c \
  skynet-src/skynet_timer.c \
  skynet-src/skynet_error.c \
  skynet-src/skynet_harbor.c \
  skynet-src/skynet_multicast.c \
  skynet-src/skynet_group.c \
  skynet-src/skynet_env.c \
  skynet-src/skynet_monitor.c \
  luacompat/compat52.c $(DEPS)
	gcc $(CFLAGS) -Iluacompat -o $@ $^ -Iskynet-src $(LDFLAGS) 

skynet-new : \
  skynet-src/skynet_main_new.c \
  skynet-src/skynet_handle.c \
  skynet-src/skynet_module.c \
  skynet-src/skynet_mq.c \
  skynet-src/skynet_server.c \
  skynet-src/skynet_start.c \
  skynet-src/skynet_timer.c \
  skynet-src/skynet_error.c \
  skynet-src/skynet_harbor.c \
  skynet-src/skynet_multicast.c \
  skynet-src/skynet_group.c \
  skynet-src/skynet_env.c \
  skynet-src/skynet_monitor.c \
  luacompat/compat52.c $(DEPS)
	gcc $(CFLAGS) -Iluacompat -o $@ $^ -Iskynet-src $(LDFLAGS)

luaclib:
	mkdir luaclib

service/tunnel.so : service-src/service_tunnel.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/multicast.so : service-src/service_multicast.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/master.so : service-src/service_master.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/harbor.so : service-src/service_harbor.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/logger.so : skynet-src/skynet_logger.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/snlua.so : service-src/service_lua.c lualib-src/lua-seri.c
	gcc $(CFLAGS) $(SHARED) -Iluacompat $^ -o $@ -Iskynet-src -Ilualib-src

ifeq ($(MAKECMDGOALS), websocket)
service/gate.so : gate/mread.c gate/ringbuffer.c gate/main.c gate/websocket.c gate/base64.c gate/sha1.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Igate -Iskynet-src
else
service/gate.so : gate/mread.c gate/ringbuffer.c gate/main.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Igate -Iskynet-src
endif

service/localcast.so : service-src/service_localcast.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

luaclib/skynet.so : lualib-src/lua-skynet.c lualib-src/lua-seri.c lualib-src/lua-remoteobj.c lualib-src/trace_service.c | luaclib
	gcc $(CFLAGS) $(SHARED) -Iluacompat $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src

service/client.so : service-src/service_client.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

service/connection.so : connection/connection.c connection/main.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iconnection

luaclib/socket.so : connection/lua-socket.c | luaclib
	gcc $(CFLAGS) $(SHARED) -Iluacompat $^ -o $@ -Iskynet-src -Iconnection

luaclib/int64.so : lua-int64/int64.c | luaclib
	gcc $(CFLAGS) $(SHARED) -Iluacompat $^ -o $@ 

luaclib/mcast.so : lualib-src/lua-localcast.c | luaclib
	gcc $(CFLAGS) $(SHARED) -Iluacompat $^ -o $@ -Iskynet-src -Iservice-src

luaclib/mysql.so : lua-mysql/lua-mysql.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ -I/usr/local/mysql/include -L/usr/local/mysql/lib -lmysqlclient -lz
#	gcc $(CFLAGS) $(SHARED) -O2 $^ -o $@ -I/usr/include/mysql -L/usr/lib64/mysql -lmysqlclient -lz

luaclib/myclib.so :lua-myclib/lua-myclib.c lua-myclib/md5.c lua-myclib/md5.h
	gcc $(CFLAGS) $(SHARED) -O2 $^ -o $@ -Imyclib

luaclib/protobuf.so :
	@make -C lua-protobuf
	@cp -fv lua-protobuf/protobuf.so $@
	@cp -fv lua-protobuf/{protobuf.lua,parser.lua} lualib/

lualib/myclib.lua : lua-myclib/myclib.lua                               
	    cp $< $@

client : client-src/client.c
	gcc $(CFLAGS) $^ -o $@ -lpthread

clean :
	@make -C lua-protobuf clean
	rm -f skynet client service/*.so luaclib/*.so skynet-new lualib/protobuf.lua lualib/parser.lua
	
