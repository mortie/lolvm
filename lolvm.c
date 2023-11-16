#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>

#define LOLVM_OPS \
	X(SETI_32) /* dest @, imm x32 */ \
	X(SETI_64) /* dest @, imm x64 */ \
	X(ADD_32)  /* dest @, a @, b @ */ \
	X(ADD_64)  /* dest @, a @, b @ */ \
	X(ADDI_32) /* dest @, a @, imm b x32 */ \
	X(ADDI_64) /* dest @, a @, imm b x64 */ \
	/* */ \
	X(BEGIN_FRAME)   /* stack_space_bytes @ */ \
	X(END_FRAME)     /* stack_space_bytes @ */ \
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

static uint32_t parse_u64(unsigned char *ptr)
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

void evaluate(unsigned char *instrs)
{
	unsigned char stack[1024];
	uint32_t callstack[64];
	size_t sptr = 0;
	size_t iptr = 0;
	size_t cptr = 0;

	#define OP_OFFSET(offset) parse_u16(&instrs[iptr + offset])

	#define OP_U32(offset) parse_u32(&instrs[iptr + offset])
	#define OP_I32(offset) ((uint32_t)OP_U32(offset))

	#define OP_U64(offset) parse_u64(&instrs[iptr + offset])
	#define OP_I64(offset) ((uint64_t)OP_U64(offset))

	#define STACK(offset) (&stack[sptr - (offset)])

	while (1) {
		printf("%s(x%02x): iptr: %zu, sptr: %zu, cptr: %zu, instr: \n", lolvm_op_name(instrs[iptr]), instrs[iptr], iptr, sptr, cptr);
		switch ((enum lolvm_op)instrs[iptr++]) {
#define X(name, n, code...) case LOL_ ## name: code iptr += n; break;
#include "instructions.x.h"
#undef X

	case LOL_BEGIN_FRAME:
		sptr += OP_OFFSET(0);
		iptr += 2;
		break;

	case LOL_END_FRAME:
		sptr -= OP_OFFSET(0);
		iptr += 2;
		break;

	case LOL_CALL:
		callstack[cptr++] = iptr + 4;
		iptr = OP_U32(0);
		break;

	case LOL_RETURN:
		iptr = callstack[--cptr];
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
	}}
}

int main ()
{
	unsigned char bytecode[] = {
		LOL_BEGIN_FRAME, 4, 0,
		LOL_SETI_32, 4, 0, 50, 0, 0, 0,
		LOL_DBG_PRINT_I32, 4, 0,
		LOL_HALT,
	};

	unsigned char bcbuf[1024 * 1024];
	memset(bcbuf, 0x7c, sizeof(bcbuf));
	memcpy(bcbuf, bytecode, sizeof(bytecode));

	evaluate(bcbuf);
}
