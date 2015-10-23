#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include "sha1.h"
#include "base64.h"
#include "websocket.h"

/* static uint32_t parser_int(const char *key) */
/* { */
/* 	char res_decimals[15] = ""; */
/* 	char *tail_res = res_decimals; */
/* 	uint8_t space_count = 0; */
/* 	uint8_t i = 0; */
/* 	do { */
/* 		if (isdigit(key[i])) */
/* 			strncat(tail_res++, &key[i], 1); */
/* 		if (key[i] == ' ') */
/* 			space_count++; */
/* 	} while (key[++i]); */
/*  */
/* 	return ((uint32_t) strtoul(res_decimals, NULL, 10) / space_count); */
/* } */

static int
get_header_value(const char *data, size_t datalen, const char *key, char *dst, size_t dstlen) 
{
	char *src = (char *)malloc( datalen + 1);
	char *start;
	char k[64];
	strcpy(k, key);
	strcat(k, ": ");
	memcpy(src, data, datalen);
	src[datalen] = '\0';
	start = strstr(src, k);
	if (start == NULL) {
		free(src);
		dst[0] = '\0';
		return -1;
	}
	start = strstr(start, ": ");
	if (start == NULL) {
		free(src);
		dst[0] = '\0';
		return -1;
	}
	start += 2;
	int i;
	for (i = 0; i < dstlen-1; i++) {
		if (start[i] == '\r') {
			break;
		}
		dst[i] = start[i];
	}
	assert(i != dstlen - 1);
	dst[i] = '\0';
	free(src);
	return 0;
}

int is_websocket_header(const char * data, size_t datalen)
{
	char value[512];
	if (get_header_value(data, datalen, "Connection", value, sizeof(value)) == 0) {
		if (strstr(value, "Upgrade")) {
			if (get_header_value(data, datalen, "Upgrade", value, 512) == 0) {
				// version 13 is 'websocket'
				if (strcasestr(value, "WebSocket")) {
					return 1;
				}
				else {
					printf("Can not found websocket in %s\n", value);
				}
			}
		}
	}
	return 0;
}

const char * generate_websocket_resp(const char * req, size_t reqlen, char * dest, size_t destlen)
{
	/* char origin[256]; */
	/* char protocol[256]; */
	/* char key1[256]; */
	/* char key2[256]; */
	char key[256];
	char upgrade[64];
	/* get_header_value(req, reqlen, "Origin", origin, sizeof(origin)); */
	/* get_header_value(req, reqlen, "Sec-WebSocket-Protocol", protocol, sizeof(protocol)); */
	get_header_value(req, reqlen, "Upgrade", upgrade, sizeof(upgrade));
	/* get_header_value(req, reqlen, "Sec-WebSocket-Key1", key1, sizeof(key1)); */
	/* get_header_value(req, reqlen, "Sec-WebSocket-Key2", key2, sizeof(key2)); */
	get_header_value(req, reqlen, "Sec-WebSocket-Key", key, sizeof(key));
	if (key[0] != '\0') {
		char key_sha1[128];
		char key_base64[128];
		SHA1Context sha;
		strcat(key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
		SHA1Reset(&sha);
		SHA1Input(&sha, ( const unsigned char * )key, strlen(key));
		SHA1Result(&sha);
		memset(key_sha1, 0, sizeof(key_sha1));
		memset(key_base64, 0, sizeof(key_base64));
		int i, j;
		for (i = 0; i < 5; i++) {
			for (j = 0; j < 4; j++) {
				key_sha1[i*4+j] = sha.Message_Digest[i] << (8*j) >> 24;
			}
		}
		base64_encode(key_sha1, strlen(key_sha1), key_base64, sizeof(key_base64));
		snprintf(dest, destlen, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: %s\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n", upgrade, key_base64);
		return dest;
	}
	return NULL;
}

/* int  */
/* parser_one_frame(const char *input, size_t input_len, char *data, size_t &data_len) */
/* { */
/* 	int ret = 0; */
/* 	if (input_len < 2) { */
/* 		return WS_INCOMPLETE_FRAME; */
/* 	} */
/* 	struct frame_header header = *(struct frame_header *)input; */
/* 	size_t mask_len = header->mask ? 4 : 0; */
/* 	if ( input_len < (2 + mask_len + header->payload_len)) { */
/* 		return WS_INCOMPLETE_FRAME; */
/* 	} */
/* 	if (header.fin == 1) { */
/* 		ret |= WS_LAST_FRAME; */
/* 	} */
/* 	switch (header.opcode) { */
/* 		case 0x0: */
/* 			break; */
/* 		case 0x1: */
/* 			ret |= WS_TEXT_FRAME; */
/* 			break; */
/* 		case 0x2: */
/* 			ret |= WS_BINARY_FRAME; */
/* 			break; */
/* 		case 0x8: */
/* 			ret |= WS_CLOSE_FRAME; */
/* 			break; */
/* 		case 0x9: */
/* 			ret |= WS_PING_FRAME; */
/* 			break; */
/* 		case 0xa: */
/* 			ret |= WS_PONG_FRAME; */
/* 			break; */
/* 		default: */
/* 			ret |= WS_RESERVED_FRAME; */
/* 			break; */
/* 	} */
/* 	return ret; */
/* } */

/* int ws_parser_data(const char *input, size_t input_len, char * out, size_t out_len) */
/* { */
/*  */
/* 	assert(input_len); */
/* 	assert(out_len); */
/*  */
/* 	if (input_len < 2) { */
/* 		return -1; */
/* 	} */
/*  */
/* 	if (input[0]&0x80) { */
/* 		// FIN: 1 */
/*  */
/* 	} */
/* } */
