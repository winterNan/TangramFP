/* profiler.h ---
 *
 * Filename: profiler.h
 * Description:
 * Author: Yuan
 * Maintainer:
 * Created: Mon Jun 10 10:49:23 2024 (+0200)
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

/* internal profiler */

#ifndef KACY_PROFILER
#define KACY_PROFILER

#include <assert.h>
#include <stdio.h>

#define DA_MAX_BRANCH 0x08 /* 8 branches */
#define DA_MAX_BIN    0x40 /* 64 bins */

#define DA_NAN        0x00
#define DA_INF        0x01
#define DA_ZS         0x02
#define DA_MINUS      0x03
#define DA_FULL       0x04
#define DA_SKIP_BD    0x05
#define DA_AC_ONLY    0x06
#define DA_SKIP_ALL   0x07

long long int bc[DA_MAX_BRANCH] = {0};
long long int bin[DA_MAX_BIN] = {0};

void da_clear_bc(){
    for (int i=0; i<DA_MAX_BRANCH; i++)
        bc[i] = 0;
}

void da_clear_bin(){
    for (int i=0; i<DA_MAX_BIN; i++)
        bin[i] = 0;
}

inline void da_sample_bc(int _branch) {
    assert(_branch < DA_MAX_BRANCH && _branch >= 0);
    bc[_branch] += 1;
}

inline void da_sample_bin(int _bin) {
    assert (_bin < DA_MAX_BIN && _bin >= 0);
    bin[_bin] += 1;
}

void print_bc(){
    printf("%-30s", "NAN");
    printf("%-30s", "INF");
    printf("%-30s", "ZS");
    printf("%-30s", "MINUS");
    printf("%-30s", "FULL");
    printf("%-30s", "SKIP_BD");
    printf("%-30s", "AC_ONLY");
    printf("%-30s", "SKIP_ALL");
    printf("\n");
    for (int i=0; i<DA_MAX_BRANCH; i++)
        printf("%-30lld", bc[i]);
    printf("\n");
}

void print_bin(){
    for (int i=0; i<DA_MAX_BIN; i++)
        printf("%-30lld", bin[i]);
    printf("\n");
}

void da_dump() {
    print_bc();
    print_bin();
    da_clear_bc();
    da_clear_bin();
}

#endif

/* profiler.h ends here */
