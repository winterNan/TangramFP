/* fp16.c ---
 *
 * Filename: fp16.c
 * Description:
 * Author: Yuan
 * Maintainer:
 * Created: Fri Jun  7 12:02:24 2024 (+0200)
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

#include "../include/kacy.h"
#include <stdio.h>
#include <stdint.h>
#include <wmmintrin.h>
#include <assert.h>

uint as_uint(const float x) { return *(uint *)&x; }
float as_float(const uint x) { return *(float *)&x; }

float half_to_float(const ushort x) {
    /* IEEE-754 16-bit floating-point
       format (without infinity):
       1-5-10, exp-15, +-131008.0,
       +-6.1035156E-5, +-5.9604645E-8,
       3.311 digits */
    const uint e = (x&EXP_MASK)>>10; // exponent
    const uint m = (x&0x03FF)<<13;   // mantissa
    const uint v = as_uint((float)m)>>23; // evil log2 bit hack to count
                                          // leading zeros in denormalized format
    return as_float((x&0x8000)<<16 | (e!=0)*((e+112)<<23|m) | \
                    ((e==0)&(m!=0))*((v-37)<<23|((m<<(150-v))&0x007FE000)));
           // sign : normalized : denormalized
}

ushort float_to_half(const float x) {
    /* IEEE-754 16-bit floating-point
       format (without infinity):
       1-5-10, exp-15, +-131008.0,
       +-6.1035156E-5, +-5.9604645E-8,
       3.311 digits */
    const uint b = as_uint(x)+0x00001000; // round-to-nearest-even:
                                          // add last bit after truncated mantissa
    const uint e = (b&0x7F800000)>>23;    // exponent
    const uint m = b&0x007FFFFF; /* mantissa; in line below:
                                    0x007FF000 = 0x00800000-0x00001000 =
                                    decimal indicator flag - initial rounding */
    return (b&0x80000000)>>16 | (e>112)*((((e-112)<<10)&EXP_MASK)|m>>13) | \
           ((e<113)&(e>101))*((((0x007FF000+m)>>(125-e))+1)>>1) |          \
           (e>143)*0x7FFF; // sign : normalized : denormalized : saturate
}

short f16_sub(short ain, short bin) {
    unsigned short a=ain;
    unsigned short b=bin;
    if(((a ^ b) & SIGN_MASK) != 0)
        return f16_add(a,b ^ SIGN_MASK);
    unsigned short sign = a & SIGN_MASK;
    a = a << 1;
    b = b << 1;
    if(a < b) {
        unsigned short x=a;
        a=b;
        b=x;
        sign ^= SIGN_MASK;
    }
    unsigned short ax = a & 0xF800;
    unsigned short bx = b & 0xF800;
    if(a >=0xf800 || b>=0xf800) {
        if(a > 0xF800 || b > 0xF800 || a==b)
            return NAN_VALUE;
        unsigned short res = sign | EXP_MASK;
        if(a == 0xf800)
            return res;
        else
            return res ^ SIGN_MASK;
    }
    int exp_diff = ax - bx;
    unsigned short exp_part  = ax;
    if(exp_diff != 0) {
        int shift = exp_diff >> 11;
        if(bx != 0)
            b = ((b & 2047) | 2048) >> shift;
        else
            b >>= (shift - 1);
    }
    else {
        if(bx == 0) {
            unsigned short res = (a-b) >> 1;
            if(res == 0)
                return res;
            return res | sign;
        }
        else {
            b=(b & 2047) | 2048;
        }
    }
    unsigned short r = a - b;
    if((r & 0xF800) == exp_part) {
        return (r>>1) | sign;
    }
    unsigned short am = (a & 2047) | 2048;
    unsigned short new_m = am - b;

    if(new_m == 0)
        return 0;
    while(exp_part !=0 && !(new_m & (2048))) {
        exp_part-=0x800;
        if(exp_part!=0)
            new_m<<=1;
    }
    return (((new_m & 2047) | exp_part) >> 1) | sign;
}


short f16_add(short a, short b) {

    if (((a ^ b) & SIGN_MASK) != 0)
        return f16_sub(a, b ^ SIGN_MASK);

    short sign = a & SIGN_MASK;

    a &= NAN_VALUE; // exp + mantissa bits
    b &= NAN_VALUE;

    if(a<b) { // Make sure that a >= b
        short x=a;
        a=b;
        b=x;
    }

    if(a >= EXP_MASK || b >= EXP_MASK) {
        if(a>EXP_MASK || b>EXP_MASK)
            return NAN_VALUE;
        return EXP_MASK | sign;
    }

    short ax = (a & EXP_MASK); // Mantissa without shifting
    short bx = (b & EXP_MASK);
    short exp_diff = ax - bx;  // exp diff without shifting
    short exp_part = ax;
    if(exp_diff != 0) { // Alignemt of b
        int shift = exp_diff >> 10; // exp_diff as an +integer
        if(bx != 0)
            b = ((b & 1023) | 1024) >> shift; // normal mantissa
        else
            b >>= (shift - 1); // subnormal mantissa
    } else {
        if(bx == 0)
            return (a + b) | sign; // subnormal result
        else
            b = (b & 1023) | 1024; // normal mantissa
    }

    short r = a + b; /* b is only the mantissa
                        a still contains the exp_diff
                        a does not have the leading 1!
                      */

    if ((r & EXP_MASK) != exp_part) {
        ushort am = (a & 1023) | 1024;
        ushort new_m = (am + b) >> 1;
        r =( exp_part + 0x400) | (1023 & new_m);
    }

    if((ushort)r >= 0x7C00u) {
        return sign | EXP_MASK;
    }
    return sign | r;
}

short f16_mul(short a, short b) {
    int sign = (a ^ b) & SIGN_MASK;

    if(IS_INVALID(a) || IS_INVALID(b)) {
        if(IS_NAN(a) || IS_NAN(b) || IS_ZERO(a) || IS_ZERO(b))
            return NAN_VALUE;
        return sign | EXP_MASK;
    }

    if(IS_ZERO(a) || IS_ZERO(b))
        return 0;

    unsigned short m1 = MANTISSA(a);
    unsigned short m2 = MANTISSA(b);

    uint32_t v=m1;
    v*=m2;

    int ax = EXPONENT(a);
    int bx = EXPONENT(b);
    ax += (ax==0);
    bx += (bx==0);
    int new_exp = ax + bx - 15;

    if(v & ((uint32_t)1<<21)) {
        v >>= 11;
        new_exp++;
    }
    else if(v & ((uint32_t)1<<20)) {
        v >>= 10;
    }
    else { // denormal
        new_exp -= 10;
        while(v >= 2048) {
            v>>=1;
            new_exp++;
        }
    }
    if(new_exp <= 0) {
        v>>=(-new_exp + 1);
        new_exp = 0;

    }
    else if(new_exp >= 31) {
        return SIGNED_INF_VALUE(sign);
    }

    return (sign) | (new_exp << 10) | (v & 1023);
}

/* fp16.c ends here */
