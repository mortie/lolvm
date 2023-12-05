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
	memcpy(STACK(OP_OFFSET(0)), &val, 8);
})

X(COPY_8, 4, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2));
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

X(ADD_8, 6, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) + *STACK(OP_OFFSET(4));
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
X(ADD_F32, 6, {
	float a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	float b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 4);
})
X(ADD_F64, 6, {
	double a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	double b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	a += b;
	memcpy(STACK(OP_OFFSET(0)), &a, 8);
})

X(ADDI_8, 5, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) + OP_U8(4);
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
})
X(EQ_32, 6, {
	uint32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a == b;
})
X(EQ_64, 6, {
	uint64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	uint64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a == b;
})
X(EQ_F32, 6, {
	float a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	float b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a == b;
})
X(EQ_F64, 6, {
	double a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	double b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a == b;
})

X(NEQ_8, 6, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) != *STACK(OP_OFFSET(4));
})
X(NEQ_32, 6, {
	uint32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	uint32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a != b;
})
X(NEQ_64, 6, {
	uint64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	uint64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a != b;
})
X(NEQ_F32, 6, {
	float a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	float b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a != b;
})
X(NEQ_F64, 6, {
	double a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	double b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a != b;
})

X(LT_U8, 6, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) < *STACK(OP_OFFSET(4));
})
X(LT_I32, 6, {
	int32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	int32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a < b;
})
X(LT_I64, 6, {
	int64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	int64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a < b;
})
X(LT_F32, 6, {
	float a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	float b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a < b;
})
X(LT_F64, 6, {
	double a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	double b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a < b;
})

X(LE_U8, 6, {
	*STACK(OP_OFFSET(0)) = *STACK(OP_OFFSET(2)) <= *STACK(OP_OFFSET(4));
})
X(LE_I32, 6, {
	int32_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	int32_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a <= b;
})
X(LE_I64, 6, {
	int64_t a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	int64_t b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a <= b;
})
X(LE_F32, 6, {
	float a;
	memcpy(&a, STACK(OP_OFFSET(2)), 4);
	float b;
	memcpy(&b, STACK(OP_OFFSET(4)), 4);
	*STACK(OP_OFFSET(0)) = a <= b;
})
X(LE_F64, 6, {
	double a;
	memcpy(&a, STACK(OP_OFFSET(2)), 8);
	double b;
	memcpy(&b, STACK(OP_OFFSET(4)), 8);
	*STACK(OP_OFFSET(0)) = a <= b;
})

X(REF, 4, {
	uint64_t val = (uint64_t)STACK(OP_OFFSET(2));
	memcpy(STACK(OP_OFFSET(0)), &val, 8);
})

X(LOAD_8, 4, {
	uint64_t src;
	memcpy(&src, STACK(OP_OFFSET(2)), 8);
	unsigned char *srcptr = (unsigned char *)src;
	*STACK(OP_OFFSET(0)) = *srcptr;
})
X(LOAD_32, 4, {
	uint64_t src;
	memcpy(&src, STACK(OP_OFFSET(2)), 8);
	unsigned char *srcptr = (unsigned char *)src;
	memcpy(STACK(OP_OFFSET(0)), srcptr, 4);
})
X(LOAD_64, 4, {
	uint64_t src;
	memcpy(&src, STACK(OP_OFFSET(2)), 8);
	unsigned char *srcptr = (unsigned char *)src;
	memcpy(STACK(OP_OFFSET(0)), srcptr, 8);
})
X(LOAD_N, 8, {
	uint64_t src;
	memcpy(&src, STACK(OP_OFFSET(2)), 8);
	unsigned char *srcptr = (unsigned char *)src;
	memcpy(STACK(OP_OFFSET(0)), srcptr, OP_U32(4));
})

X(STORE_8, 4, {
	uint64_t dest;
	memcpy(&dest, STACK(OP_OFFSET(0)), 8);
	unsigned char *destptr = (unsigned char *)dest;
	*destptr = *STACK(OP_OFFSET(2));
})
X(STORE_32, 4, {
	uint64_t dest;
	memcpy(&dest, STACK(OP_OFFSET(0)), 8);
	unsigned char *destptr = (unsigned char *)dest;
	memcpy(destptr, STACK(OP_OFFSET(2)), 4);
})
X(STORE_64, 4, {
	uint64_t dest;
	memcpy(&dest, STACK(OP_OFFSET(0)), 8);
	unsigned char *destptr = (unsigned char *)dest;
	memcpy(destptr, STACK(OP_OFFSET(2)), 8);
})
X(STORE_N, 8, {
	uint64_t dest;
	memcpy(&dest, STACK(OP_OFFSET(0)), 8);
	unsigned char *destptr = (unsigned char *)dest;
	memcpy(destptr, STACK(OP_OFFSET(2)), OP_U32(4));
})
