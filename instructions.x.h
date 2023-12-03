#ifndef X
#define X(name, n, code...)
#endif

X(SETI_8, 3, {
	uint8_t val = OP_U8(2);
	*STACK(OP_OFFSET(0)) = val;
})

X(SETI_32, 6, {
	uint32_t val = OP_U32(2);
	memcpy(STACK(OP_OFFSET(0)), &val, 4);
})

X(SETI_64, 10, {
	uint64_t val = OP_I64(2);
	memcpy(STACK(OP_OFFSET(0)), &val, 4);
})

X(COPY_32, 4, {
	memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), 4);
})

X(COPY_64, 4, {
	memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), 8);
})

X(COPY_N, 8, {
	memcpy(STACK(OP_OFFSET(0)), STACK(OP_OFFSET(2)), OP_U32(4));
})

X(ADD_32, 6, {
	uint32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 4);
})

X(ADD_64, 6, {
	uint64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	uint64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 8);
})

X(ADDI_32, 8, {
	uint32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint32_t b = OP_U32(4);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 4);
})

X(ADDI_64, 12, {
	uint64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	uint64_t b = OP_U64(4);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 8);
})

X(EQ_8, 6, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) == *STACK(OP_OFFSET(4));
});

X(EQ_32, 6, {
	uint32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a == b;
});

X(EQ_64, 6, {
	uint64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a == b;
});
