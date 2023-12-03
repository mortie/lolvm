#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <inttypes.h>

#define LOLVM_OPS \
	X(SETI_8)  /* dest @, imm x32 */ \
	X(SETI_32) /* dest @, imm x32 */ \
	X(SETI_64) /* dest @, imm x64 */ \
	X(COPY_32) /* dest @, src @ */ \
	X(COPY_64) /* dest @, src @ */ \
	X(COPY_N)  /* dest @, src @, size u32 */ \
	X(ADD_32)  /* dest @, a @, b @ */ \
	X(ADD_64)  /* dest @, a @, b @ */ \
	X(ADDI_32) /* dest @, a @, imm b x32 */ \
	X(ADDI_64) /* dest @, a @, imm b x64 */ \
	X(EQ_8)    /* dest @, a @, b @ */ \
	X(EQ_32)   /* dest @, a @, b @ */ \
	X(EQ_64)   /* dest @, a @, b @ */ \
	X(NEQ_8)    /* dest @, a @, b @ */ \
	X(NEQ_32)   /* dest @, a @, b @ */ \
	X(NEQ_64)   /* dest @, a @, b @ */ \
	X(LT_U8)    /* dest @, a @, b @ */ \
	X(LT_I32)   /* dest @, a @, b @ */ \
	X(LT_I64)   /* dest @, a @, b @ */ \
	X(LE_U8)    /* dest @, a @, b @ */ \
	X(LE_I32)   /* dest @, a @, b @ */ \
	X(LE_I64)   /* dest @, a @, b @ */ \
	/* */ \
	X(CALL)          /* stack-bump @, jump_target u32 */ \
	X(RETURN)        /* */ \
	X(BRANCH)        /* delta @ */ \
	X(BRANCH_Z)      /* cond @, delta @ */ \
	X(BRANCH_NZ)     /* cond @, delta @ */ \
	X(DBG_PRINT_U8) /* val @ */ \
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
		fprintf(stderr, "SETI_8 @%i, %u\n", OP_OFFSET(0), OP_U8(2));
		return 3;
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

	case LOL_EQ_8:
		fprintf(stderr, "EQ_8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_32:
		fprintf(stderr, "EQ_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_EQ_64:
		fprintf(stderr, "EQ_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_NEQ_8:
		fprintf(stderr, "NEQ_8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_32:
		fprintf(stderr, "NEQ_32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_NEQ_64:
		fprintf(stderr, "NEQ_64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_LT_U8:
		fprintf(stderr, "LT_U8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_I32:
		fprintf(stderr, "LT_I32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LT_I64:
		fprintf(stderr, "LT_I64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_LE_U8:
		fprintf(stderr, "LE_U8 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_I32:
		fprintf(stderr, "LE_I32 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;
	case LOL_LE_I64:
		fprintf(stderr, "LE_I64 @%i, @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2), OP_OFFSET(4));
		return 6;

	case LOL_CALL:
		fprintf(stderr, "CALL @%i, %u\n", OP_OFFSET(0), OP_U32(2));
		return 6;
	case LOL_RETURN:
		fprintf(stderr, "RETURN\n");
		return 0;

	case LOL_BRANCH:
		fprintf(stderr, "BRANCH @%i\n", OP_OFFSET(0));
		return 2;
	case LOL_BRANCH_Z:
		fprintf(stderr, "BRANCH_Z @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;
	case LOL_BRANCH_NZ:
		fprintf(stderr, "BRANCH_NZ @%i, @%i\n", OP_OFFSET(0), OP_OFFSET(2));
		return 4;

	case LOL_DBG_PRINT_U8:
		fprintf(stderr, "DBG_PRINT_U8 @%i\n", OP_OFFSET(0));
		return 2;
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

	fprintf(stderr, "Bad instruction (%02x)\n", *instr);

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
		fprintf(stderr, "%04zu ", iptr);
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
#define X(name, n, code...) case LOL_ ## name: code vm->iptr += n; break;
#include "instructions.x.h"
#undef X

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

void lolvm_debugger(struct lolvm *vm)
{
	while (!vm->halted) {
		fprintf(stderr, "sptr: %zu, cptr: %zu\n", vm->sptr, vm->cptr);
		fprintf(stderr, "%04zu: ", vm->iptr);
		size_t n = pretty_print_instruction(&vm->instrs[vm->iptr]);
		for (size_t i = 0; i < n + 1; ++i) {
			if (i == n) {
				fprintf(stderr, "%02x\n", vm->instrs[vm->iptr + i]);
			} else {
				fprintf(stderr, "%02x ", vm->instrs[vm->iptr + i]);
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

	struct lolvm vm;
	lolvm_init(&vm, bytecode);

	printf("=== Execute:\n");
	if (argv[1] && strcmp(argv[1], "--step") == 0) {
		lolvm_debugger(&vm);
	} else {
		lolvm_run(&vm);
	}
}
