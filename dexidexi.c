#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static const char *help_text =
	"dexidexi - something like dd\n"
	"\n"
	"supported options\n"
	"  bs=<integer>    : set block size (default = 1)\n"
	"  count=<integer> : set number of blocks to copy (default = 1)\n"
	"  if=<string>     : set file to read from\n"
	"  of=<string>     : set file to write into\n"
	"  seek=<integer>  : set 0-origin index of output block to begin with\n"
	"  skip=<integer>  : set 0-origin index of input block to begin with\n"
	"  --help | -h     : show this help and exit\n"
	"\n"
	"Output file won't be truncated.\n"
	"No suffix is supported for integers yet.\n"
;

int is_cmd(const char *data, const char *cmd) {
	for(;;) {
		if (*cmd == '\0') return 1;
		if (*data++ != *cmd++) return 0;
	}
}

int safe_atoi(const char *data) {
	int value;
	char *end;
	value = strtol(data, &end, 0);
	if(*end == '\0' && *data != '\0') return value; else return -1;
}

int main(int argc, char *argv[]) {
	char *in = NULL;
	char *out = NULL;
	int bs = 1;
	int count = 1;
	int seek = 0;
	int skip = 0;
	char *buffer;
	FILE* fpin;
	FILE* fpout;
	int i;
	for (i = 1; i < argc; i++) {
		if(is_cmd(argv[i], "bs=")) {
			int new_value = safe_atoi(argv[i] + 3);
			if (new_value > 0) bs = new_value;
		} else if (is_cmd(argv[i], "count=")) {
			int new_value = safe_atoi(argv[i] + 6);
			if (new_value >= 0) count = new_value;
		} else if (is_cmd(argv[i], "if=")) {
			in = argv[i] + 3;
		} else if (is_cmd(argv[i], "of=")) {
			out = argv[i] + 3;
		} else if (is_cmd(argv[i], "seek=")) {
			int new_value = safe_atoi(argv[i] + 5);
			if (new_value >= 0) seek = new_value;
		} else if (is_cmd(argv[i], "skip=")) {
			int new_value = safe_atoi(argv[i] + 5);
			if (new_value >= 0) skip = new_value;
		} else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
			fputs(help_text, stdout);
			return 0;
		}
	}
	if (in == NULL || out == NULL) {
		fputs("input or output file not specified\n", stderr);
		return 1;
	}
	buffer = malloc(bs);
	if (buffer == NULL) {
		perror("malloc");
		return 1;
	}
	fpin = fopen(in, "rb");
	if (fpin == NULL) {
		perror("fopen for read");
		free(buffer);
		return 1;
	}
	if(fseek(fpin, (long)bs * skip, SEEK_SET)) {
		perror("fseek for read");
		fclose(fpin);
		free(buffer);
		return 1;
	}
	fpout = fopen(out, "rb+");
	if (fpout == NULL && errno == ENOENT) fpout = fopen(out, "wb+");
	if (fpout == NULL) {
		perror("fopen for write");
		fclose(fpin);
		free(buffer);
		return 1;
	}
	if(fseek(fpout, (long)bs * seek, SEEK_SET)) {
		perror("fseek for write");
		fclose(fpin);
		fclose(fpout);
		free(buffer);
		return 1;
	}
	for (i = 0; i < count; i++) {
		if(fread(buffer, bs, 1, fpin) != 1) break;
		if(fwrite(buffer, bs, 1, fpout) != 1) break;
	}
	printf("copied %d blocks.\n", i);
	fclose(fpin);
	fclose(fpout);
	free(buffer);
	return 0;
}
