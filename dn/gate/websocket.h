#include <stdlib.h>
struct ws_frame_header
{
	unsigned opcode : 4;
	unsigned rsv3 : 1;
	unsigned rsv2 : 1;
	unsigned rsv1 : 1;
	unsigned fin : 1;
	unsigned payload_len : 7;
	unsigned mask : 1;
};

enum ws_frame_type 
{
	WS_INCOMPLETE_FRAME	= 1 << 0,
	WS_CLOSE_FRAME 		= 1 << 1,
	WS_UNKNOW_FRAME 	= 1 << 2,
	WS_TEXT_FRAME 		= 1 << 3,
	WS_BINARY_FRAME		= 1 << 4,
	WS_PING_FRAME		= 1 << 5,
	WS_PONG_FRAME		= 1 << 6,
	WS_ERROR_FRAME		= 1 << 7,
	WS_LAST_FRAME		= 1 << 8,
	WS_RESERVED_FRAME	= 1 << 9,
};
int is_websocket_header(const char * data, size_t datalen);
const char * generate_websocket_resp(const char * req, size_t reqlen, char * dest, size_t destlen);
