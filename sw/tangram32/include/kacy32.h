#include <stdint.h>
#ifndef KACY32_H
#define KACY32_H

#define SIGN_MASK        0x80000000
#define EXP_MASK         0x7F800000     //0x7C00
#define NAN_VALUE        0x7FFFFFFF     //0x7FFF
#define MAN_MASK         0x007FFFFF    //0x3FFF

#define IS_ZERO(x) (((x) & NAN_VALUE) == 0)
// both inf and NAN are invalid values
#define IS_INVALID(x) (((x)&EXP_MASK) == EXP_MASK)
#define IS_NAN(x) (((x) & NAN_VALUE) > EXP_MASK)
#define IS_INF(x) (((x) & NAN_VALUE) == EXP_MASK)
#define MANTISSA(x) (((x) & MAN_MASK) | (((x) & EXP_MASK) == 0 ? 0 : 0x800000))
#define EXPONENT(x) (((x) & EXP_MASK) >> 23)//10
#define SIGNED_INF_VALUE(x) ((x & SIGN_MASK) | EXP_MASK)
#define IS_SUBNORMAL(x) ((EXPONENT(x) == 0) && (MANTISSA(x) != 0))

// short f16_add(short a,short b);
// short f16_sub(short a,short b);
// short f16_mul(short a,short b);
// defining short words for unsigned short and unsigned int
typedef uint64_t uint64; // 
typedef uint32_t ushort32;// 

double kacy_f32_main(double* a, double* b, double sum,
                    short size,
                    short tangram,
                    short preb,
                    short offset);

double kacy_fp32_mult(uint32_t a, uint32_t b, 
                    short mode,
                    short cut);
uint64_t kacy_mul_core_1_X_Y(uint32_t u, uint32_t v,
                    short mode, 
                    short cut);
 double float_to_double(const ushort32);
 ushort32 double_to_float(const double);

void da_sample_bc(int);
void da_sample_bin(int);
void da_dump();

#endif
