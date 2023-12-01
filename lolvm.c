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
	X(ADD_32)  /* dest @, a @, b @ */ \
	X(ADD_64)  /* dest @, a @, b @ */ \
	X(ADDI_32) /* dest @, a @, imm b x32 */ \
	X(ADDI_64) /* dest @, a @, imm b x64 */ \
	/* */ \
	X(BEGIN_FRAME)   /* stack_space_bytes @ */ \
	X(CALL)          /* jump_target u32 */ \
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
	size_t bptr;
	size_t sptr;
	size_t iptr;
};

void evaluate(unsigned char *instrs)
{
	unsigned char stack[1024];
	struct stack_frame callstack[64];
	size_t sptr = 0;
	size_t bptr = 0;
	size_t iptr = 0;
	size_t cptr = 0;

	#define OP_OFFSET(offset) parse_u16(&instrs[iptr + offset])

	#define OP_U32(offset) parse_u32(&instrs[iptr + offset])
	#define OP_I32(offset) ((uint32_t)OP_U32(offset))

	#define OP_U64(offset) parse_u64(&instrs[iptr + offset])
	#define OP_I64(offset) ((uint64_t)OP_U64(offset))

	#define STACK(offset) (&stack[bptr - (offset)])

	while (1) switch ((enum lolvm_op)instrs[iptr++]) {
#define X(name, n, code...) case LOL_ ## name: code iptr += n; break;
#include "instructions.x.h"
#undef X

	case LOL_BEGIN_FRAME:
		sptr += OP_OFFSET(0);
		iptr += 2;
		break;

	case LOL_CALL:
		callstack[cptr].bptr = bptr;
		callstack[cptr].sptr = sptr;
		callstack[cptr].iptr = iptr + 4;
		cptr += 1;
		iptr = OP_U32(0);
		break;

	case LOL_RETURN:
		cptr -= 1;
		bptr = callstack[cptr].bptr;
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

void prettyprint(unsigned char *instrs, size_t size) {
	#define OP_OFFSET(offset) parse_u16(&instrs[iptr + offset])

	#define OP_U32(offset) parse_u32(&instrs[iptr + offset])
	#define OP_I32(offset) ((uint32_t)OP_U32(offset))

	#define OP_U64(offset) parse_u64(&instrs[iptr + offset])
	#define OP_I64(offset) ((uint64_t)OP_U64(offset))

	size_t iptr = 0;
	while (iptr < size) switch ((enum lolvm_op)instrs[iptr++]) {
	case LOL_SETI_32:
		printf("SETI_32 @%i, %u\n", OP_OFFSET(0), OP_U32(2));
		iptr += 6;
		break;

	case LOL_SETI_64:
		printf("SETI_64 @%i, %llu\n", OP_OFFSET(0), OP_U64(2));
		iptr += 10;
		break;

	case LOL_COPY_32:
		printf("COPY_32 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		iptr += 4;
		break;

	case LOL_COPY_64:
		printf("COPY_64 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		iptr += 4;
		break;

	case LOL_ADD_32:
		printf("ADD_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		iptr += 6;
		break;

	case LOL_ADD_64:
		printf("ADD_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		iptr += 6;
		break;

	case LOL_ADDI_32:
		printf("ADDI_32 @%i, @%i, %u\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		iptr += 8;
		break;

	case LOL_ADDI_64:
		printf("ADDI_64 @%i, @%i, %llu\n", OP_OFFSET(0), OP_OFFSET(2), OP_U64(4));
		iptr += 12;
		break;

	case LOL_BEGIN_FRAME:
		printf("BEGIN_FRAME %i\n", OP_OFFSET(0));
		iptr += 2;
		break;

	case LOL_CALL:
		printf("CALL %u\n", OP_U32(0));
		iptr += 4;
		break;

	case LOL_RETURN:
		printf("RETURN\n");
		break;

	case LOL_DBG_PRINT_I32:
		printf("DBG_PRINT_I32 @%i\n", OP_OFFSET(0));
		iptr += 2;
		break;

	case LOL_DBG_PRINT_I64:
		printf("DBG_PRINT_I64 @%i\n", OP_OFFSET(0));
		iptr += 2;
		break;

	case LOL_HALT:
		printf("HALT\n");
		break;
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
	prettyprint(bytecode, n);
	printf("=== Execute:\n");
	evaluate(bytecode);
}
