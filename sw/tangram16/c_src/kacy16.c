/* kacy16.c ---
 *
 * Filename: kacy16.c
 * Description:
 * Author: Yuan Yao
 * Maintainer:
 * Created: Fri Mar  1 10:45:04 2024 (+0100)
 * Version:
 * Package-Requires: ()
 * Last-Updated:
 *           By:
 *     Update #: 0
 * URL:
 * Doc URL:
 * Keywords:
 * Compatibility:
 *
 */

/* Commentary:
 *
 *
 *
 */

/* Change Log:
 *
 *
 */

/* This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
 */

/* Code: */

#include <stdio.h>
#include <stdint.h>
#include <wmmintrin.h>
#include <assert.h>

#include "../include/kacy.h"
#include "../include/profiler.h"

#define MAN_FULL         0x0B

#define FULL_X_Y         0x01
#define AC_PLUS_X_Y      0x02
#define AC_LITE_X_Y      0x03

#define FULL_1_X_Y       0x11
#define SKIP_BD_1_X_Y    0x12
#define AC_ONLY_1_X_Y    0x13

#define SKIP             0xFF

#define TANG_X_Y         0x00
#define TANG_1_X_Y       0x10

#ifdef DEBUG
#define PRINT1(ta, a)                                                         \
    do {                                                                      \
        printf("[\033[0;31m--C--\033[0m]  %s:  \t \
\033[0;33m" #ta "=%#04x \033[0m [%s:%d]\n",                                   \
               __func__, a&0xFFFF,                                            \
               __FILE__, __LINE__);                                           \
  } while (0);

#define PRINT1f(ta, a)                                                        \
    do {                                                                      \
        printf("[\033[0;31m--C--\033[0m]  %s:  \t \
\033[0;33m" #ta "=%f \033[0m [%s:%d]\n",                                      \
               __func__, a,                                                   \
               __FILE__, __LINE__);                                           \
    } while(0);

#define PRINT2(ta, a, tb, b)                                                  \
    do {                                                                      \
        printf("[\033[0;31m--C--\033[0m]  %s:  \t \
\033[0;33m"#ta"=%#04x, "#tb"=%#04x \033[0m [%s:%d]\n",                        \
               __func__, a&0xFFFF, b&0xFFFF, __FILE__, __LINE__);             \
    } while(0);

#define PRINT3(ta, a, tb, b, tc, c)                                            \
  do {                                                                         \
    printf("[\033[0;31m--C--\033[0m]  %s:   \t \
\033[0;33m" #ta "=%#04x, " #tb "=%#04x, " #tc "=%#04x \033[0m [%s:%d]\n",      \
           __func__, a & 0xFFFF, b & 0xFFFF, c & 0xFFFF, __FILE__, __LINE__);  \
  } while (0);


#define PRINT3f(ta, a, tb, b, tc, c)                                    \
    do {                                                                \
    printf("[\033[0;31m--C--\033[0m]  %s:   \t \
\033[0;33m" #ta "=%f, " #tb "=%f, " #tc "=%f \033[0m [%s:%d]\n",      \
           __func__, a, b, c, __FILE__, __LINE__);  \
  } while (0);

#else
#define PRINT1(ta, a)
#define PRINT1f(ta, a)
#define PRINT2(ta, a, tb, b)
#define PRINT3(ta, a, tb, b, tc, c)
#define PRINT3f(ta, a, tb, b, tc, c)
#endif

#define RTE(a, cut) (!!(a & (1 << (cut - 1))))

#define KACY_PANIC(reason)                                                    \
    do {                                                                      \
        printf("[%s:%d] ", __FILE__, __LINE__);                               \
        printf(#reason"\n");                                                  \
        exit(-1);                                                             \
    } while (0);

extern float half_to_float(const ushort);
extern ushort float_to_half(const float);

extern void da_sample_bc(int);
extern void da_sample_bin(int);
extern void dump();

uint32_t kacy_mul_core_1_X_Y(short u, short v, short mode, short cut) {

    assert(((u & 0x7FF)!=0) && ((v & 0x7FF)!=0));
    PRINT2("mode", mode, "cut", cut);

    uint32_t x, y, _u, _v, a, b, c, d;

    x = (u & 0x400) >> 10; y = (v & 0x400) >> 10;
    _u = u & 0x3FF; _v = v & 0x3FF;
    b = u & ((1 << cut) - 1);
    d = v & ((1 << cut) - 1);

    if (mode == FULL_1_X_Y){
        a = _u >> cut; c = _v >> cut;
        return (x*y << 20) +
               (_u << cut*2) + (_v << cut*2) +
               (a*c << cut*2) +
               ((a*d + c*b) << cut) +
               b*d;

    } else if (mode == SKIP_BD_1_X_Y){
        a = _u >> cut; c = _v >> cut;
        return (x*y << 20) +
               (_u << cut*2) + (_v << cut*2) +
               (a*c << cut*2) +
               ((a*d + c*b) << cut);

    } else if (mode == AC_ONLY_1_X_Y) {
        a = (_u >> cut) + RTE(u, cut);
        c = (_v >> cut) + RTE(u, cut);
        return (x*y << 20) +
               (_u << cut*2) + (_v << cut*2) +
               (a*c << cut*2);

    } else {
        KACY_PANIC("");
    }

    KACY_PANIC("Bang.")
}

float kacy_fp16_mult(short a, short b, short mode, short cut) {
    // Do only one time of alignment
    union {
        uint32_t i;
        float f;
    } converter;

    int sign_ab = (a ^ b) & SIGN_MASK; // 16th bit

    ushort am = MANTISSA(a);
    ushort bm = MANTISSA(b);

    uint32_t ab_v = 0;

    if (__builtin_expect(((mode & 0xF0) == 0x00),0)) {
        ab_v = kacy_mul_core_1_X_Y(am, bm, mode, cut);
    } else if (__builtin_expect(((mode & 0xF0) == 0x10),1)) {
        ab_v = kacy_mul_core_1_X_Y(am, bm, mode, cut);
    } else {
        KACY_PANIC("WRONG MODE")
    }

    int ax = EXPONENT(a);
    int bx = EXPONENT(b);
    assert (ax != 0);
    assert (bx != 0);

    int ab_exp = ax + bx - 15;

    PRINT3("ax", ax, "bx", bx, "ab_exp", ab_exp);


    if (ab_v & ((uint32_t)1<<21)) { // allignment of result
        ab_v <<= 2;
        ab_exp += 113;
    } else if (ab_v & ((uint32_t)1<<20)) {
        ab_v <<= 3;
        ab_exp += 112;
    }

    PRINT2("ab_exp", ab_exp, "av_v", ab_v);

    converter.i = ((sign_ab << 16) | (ab_exp << 23) | (ab_v & 0x7FFFFF));

    return converter.f;
}


float kacy_f16_main(float* _a, float* _b, float _sum, short size,
                    short tangram,  /* 0x10 */
                    short preb,     /* 5 */
                    short offset) { /* 0 */

    PRINT1("kacy_f16_main", 0);

    assert (tangram == TANG_1_X_Y);

    ushort sum = float_to_half(_sum);

    if (IS_INVALID(sum)) {
        if (IS_NAN(sum)){
            printf("_sum : %f, sum : %d \n", _sum, sum);
            KACY_PANIC("SUM_NAN");
            /* return half_to_float(NAN_VALUE); */
        }
        printf("_sum : %f, sum : %d \n", _sum, sum);
        KACY_PANIC("SUM_INF");
        /* return half_to_float(1 | EXP_MASK); /
           \* always return +infinity *\/ */
    }

    if (IS_SUBNORMAL(sum))
        sum = 0;

    int sumx = EXPONENT(sum);

    /* calculate the mode of each a*b pair */

    ushort a[size]; /* binary representation */
    ushort b[size];
    char zs[size];  /* pos for zero in a or b */

    for (int i=0; i<size; i++)
        zs[i] = 0;

    int max_exp = sumx; /* assume first sumx is max */
    sumx += (sumx==0);
    int exp[size];

    for (int i = 0; i < size; i++) {

        PRINT3f("a[i]", _a[i], "b[i]", _b[i], "psum", _sum);

        a[i] = float_to_half(_a[i]);
        b[i] = float_to_half(_b[i]);

        if (IS_INVALID(a[i]) || IS_INVALID(b[i])) {
            if (IS_NAN(a[i]) || IS_NAN(b[i])){
                printf("i: %d\n", i);
                for (int i=0; i<size; i++){
                    printf("_a[i] : %f, a[i] : %d \n", _a[i], a[i]);
                    printf("_b[i] : %f, b[i] : %d \n", _b[i], b[i]);
                }
                KACY_PANIC("AB_NAN");
                /* return half_to_float(NAN_VALUE); */
            }
            printf("i: %d\n", i);
            for (int i=0; i<size; i++){
                printf("_a[i] : %f, a[i] : %d \n", _a[i], a[i]);
                printf("_b[i] : %f, b[i] : %d \n", _b[i], b[i]);
            }
            KACY_PANIC("AB_INF")
            /* return half_to_float(1 | EXP_MASK); */
        }

        if (IS_ZERO(a[i]) || IS_ZERO(b[i])){
            PRINT1("AB_ZERO", 0);
            da_sample_bc(DA_ZS);
            zs[i] = 1;
        }

        if (IS_SUBNORMAL(a[i])) {
            PRINT1("A_SUB", 0);
            da_sample_bc(DA_ZS);
            a[i] = 0;
            zs[i] = 1;
        }

        if (IS_SUBNORMAL(b[i])){
            PRINT1("B_SUB", 0);
            da_sample_bc(DA_ZS);
            b[i] = 0;
            zs[i] = 1;
        }

        int ax = EXPONENT(a[i]);
        ax += (ax==0);
        int bx = EXPONENT(b[i]);
        bx += (bx==0);
        exp[i] = ax + bx - 15;

        if (max_exp <= exp[i])
            max_exp = exp[i];
    }

    short thrd_1 = preb + offset;
    short thrd_2 = MAN_FULL;
    float c = 0.0;

    for (int i=0;  i<size; i++) {

        if (zs[i]) continue;

        int exp_diff = max_exp - exp[i];
        da_sample_bin(exp_diff);

        if (exp_diff < 0){
            PRINT2("MINUS mode", FULL_1_X_Y, "exp_diff", exp_diff);
            c += _a[i] * _b[i];
            da_sample_bc(DA_MINUS);
        } else if (exp_diff == 0) {
            PRINT2("FULL mode", FULL_1_X_Y, "exp_diff", exp_diff);
            da_sample_bc(DA_FULL);
            c += kacy_fp16_mult(a[i], b[i],
                              FULL_1_X_Y,
                              preb);
        } else if (exp_diff > 0 && exp_diff < thrd_1) {
            PRINT2("Skip BD mode", SKIP_BD_1_X_Y, "exp_diff", exp_diff);
            da_sample_bc(DA_SKIP_BD);
            c += kacy_fp16_mult(a[i], b[i],
                              SKIP_BD_1_X_Y,
                              preb);
        } else if (exp_diff >= thrd_1 && exp_diff < thrd_2) {
            PRINT2("AC only mode", AC_ONLY_1_X_Y, "exp_diff", exp_diff);
            da_sample_bc(DA_AC_ONLY);
            c += kacy_fp16_mult(a[i], b[i],
                              AC_ONLY_1_X_Y,
                              preb);
        } else if (exp_diff >= thrd_2) {
            PRINT2("exp_diff > 11, skip mode", SKIP, "exp_diff", exp_diff);
            da_sample_bc(DA_SKIP_ALL);
            c += 0;
        } else {
            KACY_PANIC("Wrong MODE in TANG_1_X_Y");
        }
    }

    return c += _sum;
}

/* kacy16.c ends here */
