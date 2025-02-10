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




#include "kacy.h"
#include <stdio.h>
#include <wmmintrin.h>
#include <stdint.h>
#include <inttypes.h>

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
    uint16_t res;

    switch(_branch){

    case 0:
        a = 0x0733;
        b = 0x05cd;
        res = a * b;
        printf("a=%#04x, b=%#04x, res = %#08x \n", a, b, res);
        // result should be: 0x29c2d7
        printf("Enter to continue \n");
        break;

    case 1:
        /* a = 0x0733; */
        /* b = 0x0001; */
        /* res = xor_mul(a, b); */
        /* printf("a=%#04x, b=%#04x, res = %#08x \n", a, b, res); */
        /* printf("Enter to continue \n"); */
        /* break; */

    case 3:
        /* // 1, Naive but representative test of xormul */
        /* res = xor_mul(a, b); */
        /* printf("res = %#08x \n", res); // result should be: 0x198827 */
        /* printf("Enter to continue \n"); */
        /* getchar(); */

        // 2, print the mul-matrix of xormul
        // uint32_t num=1, _res, i, j;
        // int max = 1024;
        // printf("\t\tTable from 1 to max: %d \n", max);
        // for(i=0; i<max; i++)
        // {
        //     printf("Table of %d \n", num);
        //     for(j=1; j<=num; j++)
        //     {
        //         _res = num * j;
        //         res = xor_mul(num, j);
        //         printf("%d x %d = %d (%d) +%d  \n",
        //                 num, j, _res, res, _res - res);
        //     }
        //     printf("\n");
        //     num++;
        // }
        // getchar();

        // 3, test Intel's clmul

        /* res = clmul64(a, b); */

        /* printf("a: %#04x \n", a); */
        /* printf("b: %#04x \n", b); */
        /* printf("res: %#08x \n", res); */
        /* printf("Enter to continue \n"); */
        /* break; */

        // The result array now contains the 128-bit CLMUL multiplication result

    case 4:
        // 4, test Karatsuba algorithm
        /* while(1){ */
        /*     uint16_t pw; */
        /*     printf("Enter pw: [0<=pw<=16]. 17 to quit\n"); */
        /*     scanf("%" SCNd16, &pw); */
        /*     if(pw == 17) */
        /*         break; */
        /*     res = mul_K(a, b, pw); */

        /*     printf("a: %#04x \n", a); */
        /*     printf("b: %#04x \n", b); */
        /*     printf("res: %#08x \n", res); */
        /* } */
        /* break; */

    case 5:
        // 5, play with exp
        float aa = -0.20214844;
        float bb = -0.5;
        float rres = 0.0;

        printf("a: %f, b: %f, sum: %f \n", aa, bb, rres);

        rres = kacy_f16_main(&aa, &bb, rres, 1, 0x10, 5, 0);

        printf("res: %f \n", rres);
        break;
    }
    return 0;
}

/* main.c ends here */
