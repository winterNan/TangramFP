#ifndef KACY16_H
#define KACY16_H

#define SIGN_MASK        0x8000
#define EXP_MASK         0x7C00
#define NAN_VALUE        0x7FFF

#define IS_ZERO(x) (((x) & NAN_VALUE) == 0)
// both inf and NAN are invalid values
#define IS_INVALID(x) (((x)&EXP_MASK) == EXP_MASK)
#define IS_NAN(x) (((x) & NAN_VALUE) > EXP_MASK)
#define IS_INF(x) (((x) & NAN_VALUE) == EXP_MASK)
#define MANTISSA(x) (((x) & 0x3FF) | (((x) & EXP_MASK) == 0 ? 0 : 0x400))
#define EXPONENT(x) (((x) & EXP_MASK) >> 10)
#define SIGNED_INF_VALUE(x) ((x & SIGN_MASK) | EXP_MASK)
#define IS_SUBNORMAL(x) ((EXPONENT(x) == 0) && (MANTISSA(x) != 0))

short f16_add(short a,short b);
short f16_sub(short a,short b);
short f16_mul(short a,short b);

float kacy_f16_main(float* a, float* b, float sum,
                    short size,
                    short tangram,
                    short preb,
                    short offset);

float kacy_fp16_mult(short a, short b,
                    short mode, short cut);

void da_sample_bc(int);
void da_sample_bin(int);
void da_dump();

#endif
