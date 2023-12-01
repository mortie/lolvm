#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>

#define LOLVM_OPS \
	X(SETI_32) /* dest @, imm x32 */ \
	X(SETI_64) /* dest @, imm x64 */ \
	X(COPY_32) /* dest @, src @ */ \
	X(COPY_64) /* dest @, src @ */ \
	X(COPY_N)  /* dest @, src @, size u32 */ \
	X(ADD_32)  /* dest @, a @, b @ */ \
	X(ADD_64)  /* dest @, a @, b @ */ \
	X(ADDI_32) /* dest @, a @, imm b x32 */ \
	X(ADDI_64) /* dest @, a @, imm b x64 */ \
	/* */ \
	X(CALL)          /* stack-bump @, jump_target u32 */ \
	X(RETURN)        /* */ \
	X(DBG_PRINT_I32) /* val @ */ \
	X(DBG_PRINT_I64) /* val @ */ \
	X(HALT)          /* */ \
//

enum lolvm_op {
#define X(name) LOL_ ## name,
LOLVM_OPS
#undef X
};

static const char *lolvm_op_name(enum lolvm_op op)
{
	switch (op) {
#define X(name) case LOL_ ## name: return #name;
LOLVM_OPS
#undef X
	}

	return "<invalid>";
}

static uint16_t parse_u16(unsigned char *ptr)
{
	return 
		((uint16_t)ptr[0] << 0) | \
		((uint16_t)ptr[1] << 8);
}

static uint32_t parse_u32(unsigned char *ptr)
{
	return 
		((uint32_t)ptr[0] << 0) |
		((uint32_t)ptr[1] << 8) |
		((uint32_t)ptr[2] << 16) |
		((uint32_t)ptr[3] << 24);
}

static uint64_t parse_u64(unsigned char *ptr)
{
	return 
		((uint64_t)ptr[0] << 0) |
		((uint64_t)ptr[1] << 8) |
		((uint64_t)ptr[2] << 16) |
		((uint64_t)ptr[3] << 24) |
		((uint64_t)ptr[4] << 32) |
		((uint64_t)ptr[5] << 40) |
		((uint64_t)ptr[6] << 48) |
		((uint64_t)ptr[7] << 56);
}

struct stack_frame {
	size_t sptr;
	size_t iptr;
};

size_t pretty_print_instruction(unsigned char *instr)
{
	#define OP_OFFSET(offset) ((int16_t)parse_u16(&instr[iptr + offset]))
	#define OP_U32(offset) parse_u32(&instr[iptr + offset])
	#define OP_I32(offset) ((int32_t)OP_U32(offset))
	#define OP_U64(offset) parse_u64(&instr[iptr + offset])
	#define OP_I64(offset) ((int64_t)OP_U64(offset))

	size_t iptr = 0;
	switch ((enum lolvm_op)instr[iptr++]) {
	case LOL_SETI_32:
		fprintf(stderr, "SETI_32 @%i, %u\n", OP_OFFSET(0), OP_U32(2));
		return 6;

	case LOL_SETI_64:
		fprintf(stderr, "SETI_64 @%i, %llu\n", OP_OFFSET(0), OP_U64(2));
		return 10;

	case LOL_COPY_32:
		fprintf(stderr, "COPY_32 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;

	case LOL_COPY_64:
		fprintf(stderr, "COPY_64 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;

	case LOL_COPY_N:
		fprintf(stderr, "COPY_N @%i, @%i, %u\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;

	case LOL_ADD_32:
		fprintf(stderr, "ADD_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_ADD_64:
		fprintf(stderr, "ADD_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_ADDI_32:
		fprintf(stderr, "ADDI_32 @%i, @%i, %u\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;

	case LOL_ADDI_64:
		fprintf(stderr, "ADDI_64 @%i, @%i, %llu\n", OP_OFFSET(0), OP_OFFSET(2), OP_U64(4));
		return 12;

	case LOL_CALL:
		fprintf(stderr, "CALL @%i, %u\n", OP_OFFSET(0), OP_U32(2));
		return 6;

	case LOL_RETURN:
		fprintf(stderr, "RETURN\n");
		return 0;

	case LOL_DBG_PRINT_I32:
		fprintf(stderr, "DBG_PRINT_I32 @%i\n", OP_OFFSET(0));
		return 2;

	case LOL_DBG_PRINT_I64:
		fprintf(stderr, "DBG_PRINT_I64 @%i\n", OP_OFFSET(0));
		return 2;

	case LOL_HALT:
		fprintf(stderr, "HALT\n");
		return 0;
	}

	#undef OP_OFFSET
	#undef OP_U32
	#undef OP_I32
	#undef OP_U64
	#undef OP_I64

	return 0;
}

void evaluate(unsigned char *instrs)
{
	unsigned char stack[1024];
	struct stack_frame callstack[64];
	size_t sptr = 0;
	size_t iptr = 0;
	size_t cptr = 0;

	#define OP_OFFSET(offset) ((int16_t)parse_u16(&instrs[iptr + offset]))
	#define OP_U32(offset) parse_u32(&instrs[iptr + offset])
	#define OP_I32(offset) ((int32_t)OP_U32(offset))
	#define OP_U64(offset) parse_u64(&instrs[iptr + offset])
	#define OP_I64(offset) ((int64_t)OP_U64(offset))
	#define STACK(offset) (&stack[sptr + (offset)])

	while (1) switch ((enum lolvm_op)instrs[iptr++]) {
#define X(name, n, code...) case LOL_ ## name: code iptr += n; break;
#include "instructions.x.h"
#undef X

	case LOL_CALL:
		callstack[cptr].sptr = sptr;
		callstack[cptr].iptr = iptr + 6;
		cptr += 1;
		sptr += OP_OFFSET(0);
		iptr = OP_U32(2);
		break;

	case LOL_RETURN:
		cptr -= 1;
		sptr = callstack[cptr].sptr;
		iptr = callstack[cptr].iptr;
		break;

	case LOL_DBG_PRINT_I32: {
		int32_t val;
		memcpy(&val, STACK(OP_OFFSET(0)), 4);
		printf("DBG PRINT @%" PRIi16 ": %" PRIi32 "\n", OP_OFFSET(0), val);
		iptr += 2;
		break;
	}

	case LOL_DBG_PRINT_I64: {
		int64_t val;
		memcpy(&val, STACK(OP_OFFSET(0)), 8);
		printf("DBG PRINT @%" PRIi16 ": %" PRIi64 "\n", OP_OFFSET(0), val);
		iptr += 2;
		break;
	}

	case LOL_HALT:
		return;
	}

	#undef OP_OFFSET
	#undef OP_U32
	#undef OP_I32
	#undef OP_U64
	#undef OP_I64
	#undef STACK
}

void pretty_print(unsigned char *instrs, size_t size) {
	size_t iptr = 0;
	while (iptr < size)  {
		iptr += pretty_print_instruction(&instrs[iptr]) + 1;
	}
}

int main ()
{
	printf("=== Loading: test.blol\n");
	unsigned char bytecode[1024];
	bytecode[0] = LOL_HALT;
	FILE *f = fopen("test.blol", "rb");
	if (!f) {
		return 1;
	}

	size_t n = fread(bytecode, 1, sizeof(bytecode), f);
	fclose(f);

	printf("=== Pretty print:\n");
	pretty_print(bytecode, n);
	printf("=== Execute:\n");
	evaluate(bytecode);
}
