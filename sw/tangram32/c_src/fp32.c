/* fp32.c ---
 *
 * Filename: fp32.c
 * Description:
 * Author: Mojeb, Yuan
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

#include "../include/kacy32.h"
#include <stdio.h>
#include <stdint.h>
#include <wmmintrin.h>
#include <assert.h>

uint64 as_uint64(const double x) { return *(uint64 *)&x; }
double as_double(const uint64 x) { return *(double *)&x; }
//CONVERTS FLOAT SINGLE-PRECISION 32 BIT TO DOUBLE-PRECISION 64 BIT
double float_to_double(const ushort32 x) {
    /* IEEE-754 32-bit floating-point
       format (without infinity):
       1-8-23, exp-128, +-131008.0,
       +-6.1035156E-5, +-5.9604645E-8,
       3.311 digits */
    const uint64 e = (x&EXP_MASK)>>23; // exponent 10
    const uint64 m1 = (x&0x7FFFFF);
    const uint64 m = m1<<29;   // mantissa 13
    const uint64 v = as_uint64((double)m)>>52; // evil log2 bit hack to count
                                          // leading zeros in denormalized format
    
    return as_double((x&(uint64)0x80000000)<<32 | (e!=0)*((e+896)<<29|m) | \
                    ((e==0)&(m!=0))*((v-178)<<52|((m<<(1075-v))&0xFFFFFE0000000)));
                                 // sign : normalized : denormalized   
}


ushort32 double_to_float(const double x) {
    /* IEEE-754 16-bit floating-point
       format (without infinity):
       1-5-10, exp-15, +-131008.0,
       +-6.1035156E-5, +-5.9604645E-8,
       3.311 digits */
    const uint64 b = as_uint64(x)+0x10000000; // round-to-nearest-even:
                                          // add last bit after truncated mantissa
    const ushort32 e = (b&0x7FF0000000000000)>>52;    // exponent
    const uint64 m = b&0xFFFFFFFFFFFFF; /* mantissa; in line below:
                                    0x007FF000 = 0x00800000-0x00001000 =
                                    decimal indicator flag - initial rounding */
   
    return (b&0x8000000000000000)>>32 | (e>896)*((((e-896)<<23)&EXP_MASK)|m>>29) | \
           ((e<897)&(e>872))*((((0x000FFFFFF0000000+m)>>(925-e))+1)>>1) |          \
           (e>1151)*0x7FFFFFFF; // sign : normalized : denormalized : saturate
}

/* fp32.c ends here */
