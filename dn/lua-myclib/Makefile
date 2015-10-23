md5 : mylib.o md5.o
	gcc -o md5 mylib.o md5.o
mylib.o:mylib.c md5.h
	gcc -c -I mylib.c
md5.o: md5.c md5.h
	gcc -c md5.c
clean:
	rm md5 mylib.o md5.o
