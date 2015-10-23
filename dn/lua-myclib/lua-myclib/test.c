#include "md5.h"
#include "string.h"
#include "stdio.h"

int main()
{
	const char* msg = "abcdefg";
	MD5_CTX ctx;
	unsigned int len = strlen(msg);
	printf("%s,   %d\n", msg, len);
	unsigned char ret[16];
	MD5Init(&ctx);
	MD5Update(&ctx, msg, len);
	MD5Final(ret, &ctx);
	int i;
	for(i = 0; i < 16; i ++)
		printf("%02x", ret[i]);
	putchar('\n');
	printf("%s", ret);
	return 0;	
}
