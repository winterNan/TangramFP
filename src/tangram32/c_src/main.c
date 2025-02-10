/* main.c ---
 *
 * Filename: main.c
 * Description:
 * Author: Yuan
 * Maintainer:
 * Created: Sun Jun  2 23:14:50 2024 (+0200)
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




//#include "../include/kacy.h"
#include "../include/kacy32.h"
#include <stdio.h>
#include <wmmintrin.h>
#include <stdint.h>
#include <inttypes.h>
#include <time.h>
#include <math.h>
#include "../include/test.h"

double as_double(const uint64 x) ;
ushort32 double_to_float(double x);
uint32_t clmul64(uint32_t a, uint32_t b) {
    __m128i xmm_a = _mm_cvtsi64_si128(a);
    __m128i xmm_b = _mm_cvtsi64_si128(b);

    __m128i xmm_result = _mm_clmulepi64_si128(xmm_a, xmm_b, 0x00);

    uint64_t result;
    _mm_store_si128((__m128i*)&result, xmm_result);

    return result;
}

int main(int argc, char **argv){

    // Welcome to the monkey testing land.

    int _branch = atoi(argv[1]);
    uint16_t a;
    uint16_t b;
    uint32_t res;

    switch(_branch){
    case 0:
        // union {
        //     float f;
        //     uint32_t i;
        // } converter;
       
        // ushort32 U = (ushort32)0x7FFFFF;

        //double R =  float_to_double(U);
        //printf(" result: %.18g\nexpected %.18g", R, as_double(0x380fffffc0000000));
        // converter.i =  double_to_float(0.6512984642e-45);
        // printf(" result: %#016lx, float result : %18g", converter.i, converter.f);
        //  break;
    case 1:
        // 5, play with exp
        // float x = -0.000121951104;//0.20214844;
        // float y = -0.5;
        // double result = 0.0;

        // printf("a: %f, b: %4f, sum: %4f \n", x, y, result);

        // result = kacy_f32_main(&x, &y, result, 1, 0x10, 11, 0);

        // printf("res: %.12f \n", result);
        // printf("cast down %#016llx \n", (ushort32)0x000FFFFFF0000000);
        // break;
    
    case 2:
    run_f32_mult_tests(1000);
    
    break;
    case 3:
        run_mac_tests(1000000,11,11);
        break;
    }
    
    
    return 0;
}

/* main.c ends here */
