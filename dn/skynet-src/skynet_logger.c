#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>

struct logger {
	FILE * handle;
	int pid;
	int close;
};

struct logger *
logger_create(void) {
	struct logger * inst = malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->pid = getpid();
	inst->close = 0;
	return inst;
}

void
logger_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	free(inst);
}

static int
_logger(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct logger * inst = ud;
	time_t tnow;
	struct tm tm;
	tnow = time(NULL);
	localtime_r(&tnow, &tm);
	fprintf(inst->handle, "[%04d-%02d-%02d %02d:%02d:%02d %d :%x] ", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, inst->pid, source);
	fwrite(msg, sz , 1, inst->handle);
	fprintf(inst->handle, "\n");
	fflush(inst->handle);
	return 0;
}

int
logger_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		inst->handle = fopen(parm,"a");
		if (inst->handle == NULL) {
			return 1;
		}
		inst->close = 1;
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, _logger);
		skynet_command(ctx, "REG", ".logger");
		return 0;
	}
	return 1;
}
