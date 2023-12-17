#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>

#define LOLVM_OPS \
	X(SETI_8)   /* dest @, imm x32 */ \
	X(SETI_32)  /* dest @, imm x32 */ \
	X(SETI_64)  /* dest @, imm x64 */ \
	X(COPY_8)   /* dest @, src @ */ \
	X(COPY_32)  /* dest @, src @ */ \
	X(COPY_64)  /* dest @, src @ */ \
	X(COPY_N)   /* dest @, src @, size u32 */ \
	X(ADD_8)    /* dest @, a @, b @ */ \
	X(ADD_32)   /* dest @, a @, b @ */ \
	X(ADD_64)   /* dest @, a @, b @ */ \
	X(ADD_F32)  /* dest @, a @, b @ */ \
	X(ADD_F64)  /* dest @, a @, b @ */ \
	X(ADDI_8)   /* dest @, a @, imm b x32 */ \
	X(ADDI_32)  /* dest @, a @, imm b x32 */ \
	X(ADDI_64)  /* dest @, a @, imm b x64 */ \
	X(EQ_8)     /* dest @, a @, b @ */ \
	X(EQ_32)    /* dest @, a @, b @ */ \
	X(EQ_64)    /* dest @, a @, b @ */ \
	X(EQ_F32)   /* dest @, a @, b @ */ \
	X(EQ_F64)   /* dest @, a @, b @ */ \
	X(NEQ_8)    /* dest @, a @, b @ */ \
	X(NEQ_32)   /* dest @, a @, b @ */ \
	X(NEQ_64)   /* dest @, a @, b @ */ \
	X(NEQ_F32)  /* dest @, a @, b @ */ \
	X(NEQ_F64)  /* dest @, a @, b @ */ \
	X(LT_U8)    /* dest @, a @, b @ */ \
	X(LT_I32)   /* dest @, a @, b @ */ \
	X(LT_I64)   /* dest @, a @, b @ */ \
	X(LT_F32)   /* dest @, a @, b @ */ \
	X(LT_F64)   /* dest @, a @, b @ */ \
	X(LE_U8)    /* dest @, a @, b @ */ \
	X(LE_I32)   /* dest @, a @, b @ */ \
	X(LE_I64)   /* dest @, a @, b @ */ \
	X(LE_F32)   /* dest @, a @, b @ */ \
	X(LE_F64)   /* dest @, a @, b @ */ \
	X(REF)      /* dest @, src @ */ \
	X(LOAD_8)   /* dest @, src @ */ \
	X(LOAD_32)  /* dest @, src @ */ \
	X(LOAD_64)  /* dest @, src @ */ \
	X(LOAD_N)   /* dest @, src @, size u32 */ \
	X(STORE_8)  /* dest @, src @ */ \
	X(STORE_32) /* dest @, src @ */ \
	X(STORE_64) /* dest @, src @ */ \
	X(STORE_N)  /* dest @, src @, size u32 */ \
	/* */ \
	X(CALL)          /* stack-bump @, jump_target u32 */ \
	X(RETURN)        /* */ \
	X(BRANCH)        /* delta @ */ \
	X(BRANCH_Z)      /* cond @, delta @ */ \
	X(BRANCH_NZ)     /* cond @, delta @ */ \
	X(DBG_PRINT_U8) /* val @ */ \
	X(DBG_PRINT_I32) /* val @ */ \
	X(DBG_PRINT_I64) /* val @ */ \
	X(DBG_PRINT_F32) /* val @ */ \
	X(DBG_PRINT_F64) /* val @ */ \
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

size_t pretty_print_instruction(unsigned char *instr)
{
	#define OP_U8(offset) (instr[iptr + offset])
	#define OP_OFFSET(offset) ((int16_t)parse_u16(&instr[iptr + offset]))
	#define OP_U32(offset) parse_u32(&instr[iptr + offset])
	#define OP_I32(offset) ((int32_t)OP_U32(offset))
	#define OP_U64(offset) parse_u64(&instr[iptr + offset])
	#define OP_I64(offset) ((int64_t)OP_U64(offset))

	size_t iptr = 0;
	switch ((enum lolvm_op)instr[iptr++]) {
	case LOL_SETI_8:
		printf("SETI_8 @%i, %" PRIu8 "\n", OP_OFFSET(0), OP_U8(2));
		return 3;
	case LOL_SETI_32:
		printf("SETI_32 @%i, %" PRId32 "\n", OP_OFFSET(0), OP_U32(2));
		return 6;
	case LOL_SETI_64:
		printf("SETI_64 @%i, %" PRId64 "\n", OP_OFFSET(0), OP_U64(2));
		return 10;

	case LOL_COPY_8:
		printf("COPY_8 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_COPY_32:
		printf("COPY_32 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_COPY_64:
		printf("COPY_64 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_COPY_N:
		printf("COPY_N @%i, @%i, %" PRIu32 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;

	case LOL_ADD_8:
		printf("ADD_8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_ADD_32:
		printf("ADD_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_ADD_64:
		printf("ADD_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_ADD_F32:
		printf("ADD_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_ADD_F64:
		printf("ADD_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_ADDI_8:
		printf("ADDI_32 @%i, @%i, %" PRIu8 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U8(4));
		return 5;
	case LOL_ADDI_32:
		printf("ADDI_32 @%i, @%i, %" PRId32 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;
	case LOL_ADDI_64:
		printf("ADDI_64 @%i, @%i, %" PRId64 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U64(4));
		return 12;

	case LOL_EQ_8:
		printf("EQ_8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_32:
		printf("EQ_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_64:
		printf("EQ_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_F32:
		printf("EQ_F32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_F64:
		printf("EQ_F64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_NEQ_8:
		printf("NEQ_8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_32:
		printf("NEQ_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_64:
		printf("NEQ_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_F32:
		printf("NEQ_F32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_F64:
		printf("NEQ_F64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_LT_U8:
		printf("LT_U8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_I32:
		printf("LT_I32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_I64:
		printf("LT_I64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_F32:
		printf("LT_F32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_F64:
		printf("LT_F64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_LE_U8:
		printf("LE_U8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_I32:
		printf("LE_I32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_I64:
		printf("LE_I64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_F32:
		printf("LE_F32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_F64:
		printf("LE_F64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_REF:
		printf("REF @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;

	case LOL_LOAD_8:
		printf("LOAD_8 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_LOAD_32:
		printf("LOAD_32 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_LOAD_64:
		printf("LOAD_64 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_LOAD_N:
		printf("LOAD_N @%i, @%i, %" PRIu32 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;

	case LOL_STORE_8:
		printf("STORE_8 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_STORE_32:
		printf("STORE_32 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_STORE_64:
		printf("STORE_64 @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_STORE_N:
		printf("STORE_N @%i, @%i, %" PRIu32 "\n", OP_OFFSET(0), OP_OFFSET(2), OP_U32(4));
		return 8;

	case LOL_CALL:
		printf("CALL @%i, %u\n", OP_OFFSET(0), OP_U32(2));
		return 6;
	case LOL_RETURN:
		printf("RETURN\n");
		return 0;

	case LOL_BRANCH:
		printf("BRANCH @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_BRANCH_Z:
		printf("BRANCH_Z @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_BRANCH_NZ:
		printf("BRANCH_NZ @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;

	case LOL_DBG_PRINT_U8:
		printf("DBG_PRINT_U8 @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_DBG_PRINT_I32:
		printf("DBG_PRINT_I32 @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_DBG_PRINT_I64:
		printf("DBG_PRINT_I64 @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_DBG_PRINT_F32:
		printf("DBG_PRINT_I32 @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_DBG_PRINT_F64:
		printf("DBG_PRINT_I64 @%i\n", OP_OFFSET(0));
		return 2;

	case LOL_HALT:
		printf("HALT\n");
		return 0;
	}

	printf("Bad instruction (%02x)\n", *instr);

	#undef OP_U8
	#undef OP_OFFSET
	#undef OP_U32
	#undef OP_I32
	#undef OP_U64
	#undef OP_I64

	return 0;
}

void pretty_print(unsigned char *instrs, size_t size) {
	size_t iptr = 0;
	while (iptr < size)  {
		printf("%04zu ", iptr);
		iptr += pretty_print_instruction(&instrs[iptr]) + 1;
	}
}

struct lolvm_stack_frame {
	size_t sptr;
	size_t iptr;
};

struct lolvm {
	unsigned char *instrs;
	size_t iptr;
	size_t sptr;
	size_t cptr;
	int halted;
	unsigned char stack[1024];
	struct lolvm_stack_frame callstack[64];
};

void lolvm_init(struct lolvm *vm, unsigned char *instrs)
{
	vm->instrs = instrs;
	vm->sptr = 0;
	vm->iptr = 0;
	vm->cptr = 0;
	vm->halted = 0;

	memset(&vm->stack, 0xFF, sizeof(vm->stack));
	memset(&vm->callstack, 0xFF, sizeof(vm->callstack));
}

void lolvm_step(struct lolvm *vm)
{
	#define OP_U8(offset) (vm->instrs[vm->iptr + offset])
	#define OP_OFFSET(offset) ((int16_t)parse_u16(&vm->instrs[vm->iptr + offset]))
	#define OP_U32(offset) parse_u32(&vm->instrs[vm->iptr + offset])
	#define OP_I32(offset) ((int32_t)OP_U32(offset))
	#define OP_U64(offset) parse_u64(&vm->instrs[vm->iptr + offset])
	#define OP_I64(offset) ((int64_t)OP_U64(offset))
	#define STACK(offset) (&vm->stack[vm->sptr + (offset)])

	switch ((enum lolvm_op)vm->instrs[vm->iptr++]) {
	case LOL_SETI_8: {
		uint8_t val = OP_U8(2);
		*STACK(OP_OFFSET(0)) = val;
		vm->iptr += 3;
		break;
	}
	case LOL_SETI_32: {
		uint32_t val = OP_U32(2);
		memcpy(STACK(OP_OFFSET(0)), &val, 4);
		vm->iptr += 6;
		break;
	}
	case LOL_SETI_64: {
		uint64_t val = OP_I64(2);
		memcpy(STACK(OP_OFFSET(0)), &val, 8);
		vm->iptr += 10;
		break;
	}

	case LOL_COPY_8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2));
		vm->iptr += 4;
		break;
	}
	case LOL_COPY_32: {
		memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), 4);
		vm->iptr += 4;
		break;
	}
	case LOL_COPY_64: {
		memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), 8);
		vm->iptr += 4;
		break;
	}
	case LOL_COPY_N: {
		memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), OP_U32(4));
		vm->iptr += 8;
		break;
	}

	case LOL_ADD_8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) + *STACK(OP_OFFSET(4));
		vm->iptr += 6;
		break;
	}
	case LOL_ADD_32: {
		uint32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		uint32_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 4);
		vm->iptr += 6;
		break;
	}
	case LOL_ADD_64: {
		uint64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		uint64_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 8);
		vm->iptr += 6;
		break;
	}
	case LOL_ADD_F32: {
		float a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		float b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 4);
		vm->iptr += 6;
		break;
	}
	case LOL_ADD_F64: {
		double a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		double b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 8);
		vm->iptr += 6;
		break;
	}

	case LOL_ADDI_8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) + OP_U8(4);
		vm->iptr += 5;
		break;
	}
	case LOL_ADDI_32: {
		uint32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		uint32_t b = OP_U32(4);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 4);
		vm->iptr += 8;
		break;
	}
	case LOL_ADDI_64: {
		uint64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		uint64_t b = OP_U64(4);
		a += b;
		memcpy(STACK(OP_OFFSET(0)), &a, 8);
		vm->iptr += 12;
		break;
	}

	case LOL_EQ_8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) == *STACK(OP_OFFSET(4));
		vm->iptr += 6;
		break;
	}
	case LOL_EQ_32: {
		uint32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		uint32_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a == b;
		vm->iptr += 6;
		break;
	}
	case LOL_EQ_64: {
		uint64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		uint64_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a == b;
		vm->iptr += 6;
		break;
	}
	case LOL_EQ_F32: {
		float a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		float b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a == b;
		vm->iptr += 6;
		break;
	}
	case LOL_EQ_F64: {
		double a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		double b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a == b;
		vm->iptr += 6;
		break;
	}

	case LOL_NEQ_8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) != *STACK(OP_OFFSET(4));
		vm->iptr += 6;
		break;
	}
	case LOL_NEQ_32: {
		uint32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		uint32_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a != b;
		vm->iptr += 6;
		break;
	}
	case LOL_NEQ_64: {
		uint64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		uint64_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a != b;
		vm->iptr += 6;
		break;
	}
	case LOL_NEQ_F32: {
		float a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		float b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a != b;
		vm->iptr += 6;
		break;
	}
	case LOL_NEQ_F64: {
		double a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		double b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a != b;
		vm->iptr += 6;
		break;
	}

	case LOL_LT_U8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) < *STACK(OP_OFFSET(4));
		vm->iptr += 6;
		break;
	}
	case LOL_LT_I32: {
		int32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		int32_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a < b;
		vm->iptr += 6;
		break;
	}
	case LOL_LT_I64: {
		int64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		int64_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a < b;
		vm->iptr += 6;
		break;
	}
	case LOL_LT_F32: {
		float a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		float b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a < b;
		vm->iptr += 6;
		break;
	}
	case LOL_LT_F64: {
		double a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		double b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a < b;
		vm->iptr += 6;
		break;
	}

	case LOL_LE_U8: {
		*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) <= *STACK(OP_OFFSET(4));
		vm->iptr += 6;
		break;
	}
	case LOL_LE_I32: {
		int32_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		int32_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a <= b;
		vm->iptr += 6;
		break;
	}
	case LOL_LE_I64: {
		int64_t a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		int64_t b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a <= b;
		vm->iptr += 6;
		break;
	}
	case LOL_LE_F32: {
		float a;
		memcpy(&a, STACK(OP_OFFSET(2)), 4);
		float b;
		memcpy(&b, STACK(OP_OFFSET(4)), 4);
		*STACK(OP_OFFSET(0)) = a <= b;
		vm->iptr += 6;
		break;
	}
	case LOL_LE_F64: {
		double a;
		memcpy(&a, STACK(OP_OFFSET(2)), 8);
		double b;
		memcpy(&b, STACK(OP_OFFSET(4)), 8);
		*STACK(OP_OFFSET(0)) = a <= b;
		vm->iptr += 6;
		break;
	}

	case LOL_REF: {
		uint64_t val = (uint64_t)STACK(OP_OFFSET(2));
		memcpy(STACK(OP_OFFSET(0)), &val, 8);
		vm->iptr += 4;
		break;
	}

	case LOL_LOAD_8: {
		uint64_t src;
		memcpy(&src, STACK(OP_OFFSET(2)), 8);
		unsigned char *srcptr = (unsigned char *)src;
		*STACK(OP_OFFSET(0)) = *srcptr;
		vm->iptr += 4;
		break;
	}
	case LOL_LOAD_32: {
		uint64_t src;
		memcpy(&src, STACK(OP_OFFSET(2)), 8);
		unsigned char *srcptr = (unsigned char *)src;
		memcpy(STACK(OP_OFFSET(0)), srcptr, 4);
		vm->iptr += 4;
		break;
	}
	case LOL_LOAD_64: {
		uint64_t src;
		memcpy(&src, STACK(OP_OFFSET(2)), 8);
		unsigned char *srcptr = (unsigned char *)src;
		memcpy(STACK(OP_OFFSET(0)), srcptr, 8);
		vm->iptr += 4;
		break;
	}
	case LOL_LOAD_N: {
		uint64_t src;
		memcpy(&src, STACK(OP_OFFSET(2)), 8);
		unsigned char *srcptr = (unsigned char *)src;
		memcpy(STACK(OP_OFFSET(0)), srcptr, OP_U32(4));
		vm->iptr += 8;
		break;
	}

	case LOL_STORE_8: {
		uint64_t dest;
		memcpy(&dest, STACK(OP_OFFSET(0)), 8);
		unsigned char *destptr = (unsigned char *)dest;
		*destptr = *STACK(OP_OFFSET(2));
		vm->iptr += 4;
		break;
	}
	case LOL_STORE_32: {
		uint64_t dest;
		memcpy(&dest, STACK(OP_OFFSET(0)), 8);
		unsigned char *destptr = (unsigned char *)dest;
		memcpy(destptr, STACK(OP_OFFSET(2)), 4);
		vm->iptr += 4;
		break;
	}
	case LOL_STORE_64: {
		uint64_t dest;
		memcpy(&dest, STACK(OP_OFFSET(0)), 8);
		unsigned char *destptr = (unsigned char *)dest;
		memcpy(destptr, STACK(OP_OFFSET(2)), 8);
		vm->iptr += 4;
		break;
	}
	case LOL_STORE_N: {
		uint64_t dest;
		memcpy(&dest, STACK(OP_OFFSET(0)), 8);
		unsigned char *destptr = (unsigned char *)dest;
		memcpy(destptr, STACK(OP_OFFSET(2)), OP_U32(4));
		vm->iptr += 8;
		break;
	}

	case LOL_CALL:
		vm->callstack[vm->cptr].sptr = vm->sptr;
		vm->callstack[vm->cptr].iptr = vm->iptr + 6;
		vm->cptr += 1;
		vm->sptr += OP_OFFSET(0);
		vm->iptr = OP_U32(2);
		break;
	case LOL_RETURN:
		vm->cptr -= 1;
		vm->sptr = vm->callstack[vm->cptr].sptr;
		vm->iptr = vm->callstack[vm->cptr].iptr;
		break;

	case LOL_BRANCH:
		vm->iptr += OP_OFFSET(0) - 1;
		break;
	case LOL_BRANCH_Z:
		if (*STACK(OP_OFFSET(0)) == 0) {
			vm->iptr += OP_OFFSET(2) - 1;
		} else {
			vm->iptr += 4;
		}
		break;
	case LOL_BRANCH_NZ:
		if (*STACK(OP_OFFSET(0)) != 0) {
			vm->iptr += OP_OFFSET(2) - 1;
		} else {
			vm->iptr += 4;
		}
		break;

	case LOL_DBG_PRINT_U8: {
		uint8_t val = *STACK(OP_OFFSET(0));
		printf("DBG PRINT @%" PRIi16 ": %" PRIu8 "\n", OP_OFFSET(0), val);
		vm->iptr += 2;
		break;
	}
	case LOL_DBG_PRINT_I32: {
		int32_t val;
		memcpy(&val, STACK(OP_OFFSET(0)), 4);
		printf("DBG PRINT @%" PRIi16 ": %" PRIi32 "\n", OP_OFFSET(0), val);
		vm->iptr += 2;
		break;
	}
	case LOL_DBG_PRINT_I64: {
		int64_t val;
		memcpy(&val, STACK(OP_OFFSET(0)), 8);
		printf("DBG PRINT @%" PRIi16 ": %" PRIi64 "\n", OP_OFFSET(0), val);
		vm->iptr += 2;
		break;
	}
	case LOL_DBG_PRINT_F32: {
		float val;
		memcpy(&val, STACK(OP_OFFSET(0)), 4);
		printf("DBG PRINT @%" PRIi16 ": %g\n", OP_OFFSET(0), val);
		vm->iptr += 2;
		break;
	}
	case LOL_DBG_PRINT_F64: {
		double val;
		memcpy(&val, STACK(OP_OFFSET(0)), 8);
		printf("DBG PRINT @%" PRIi16 ": %g\n", OP_OFFSET(0), val);
		vm->iptr += 2;
		break;
	}

	case LOL_HALT:
		vm->halted = 1;
		break;
	}

	#undef OP_U8
	#undef OP_OFFSET
	#undef OP_U32
	#undef OP_I32
	#undef OP_U64
	#undef OP_I64
	#undef STACK
}

void lolvm_run(struct lolvm *vm)
{
	while (!vm->halted) {
		lolvm_step(vm);
	}
}

void lolvm_step_manually(struct lolvm *vm)
{
	while (!vm->halted) {
		printf("sptr: %zu, cptr: %zu\n", vm->sptr, vm->cptr);
		printf("%04zu: ", vm->iptr);
		size_t n = pretty_print_instruction(&vm->instrs[vm->iptr]);
		for (size_t i = 0; i < n + 1; ++i) {
			if (i == n) {
				printf("%02x\n", vm->instrs[vm->iptr + i]);
			} else {
				printf("%02x ", vm->instrs[vm->iptr + i]);
			}
		}

		int ch = getchar();
		if (ch == 'c') {
			lolvm_run(vm);
			return;
		}

		lolvm_step(vm);
	}
}

int main(int argc, char **argv)
{
	int do_print = 0;
	int do_step = 0;
	int do_run = -1;
	const char *path = NULL;

	for (int i = 1; i < argc; ++i) {
		if (strcmp(argv[i], "--step") == 0) {
			do_step = 1;
			if (do_run < 0) do_run = 0;
		} else if (strcmp(argv[i], "--print") == 0) {
			do_print = 1;
			if (do_run < 0) do_run = 0;
		} else if (strcmp(argv[i], "--run") == 0) {
			do_run = 1;
		} else if (argv[i][0] == '-') {
			printf("Unknown option: %s\n", argv[i]);
			return 1;
		} else {
			path = argv[i];
		}
	}

	if (do_run < 0) {
		do_run = 1;
	}

	if (!path) {
		printf("Usage: %s <path>\n", argv[0]);
		return 1;
	}

	unsigned char bytecode[1024];
	bytecode[0] = LOL_HALT;
	FILE *f = fopen(path, "rb");
	if (!f) {
		return 1;
	}

	size_t n = fread(bytecode, 1, sizeof(bytecode), f);
	fclose(f);

	if (do_print) {
		pretty_print(bytecode, n);
	}

	if (do_step) {
		struct lolvm vm;
		lolvm_init(&vm, bytecode);
		lolvm_step_manually(&vm);
	}

	if (do_run) {
		struct lolvm vm;
		lolvm_init(&vm, bytecode);
		lolvm_run(&vm);
	}
}
