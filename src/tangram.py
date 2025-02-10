# kacy.py ---
#
# Filename: kacy.py
# Description:
# Author: Yuan
# Maintainer:
# Created: Tue Jun 11 13:41:19 2024 (+0200)
# Version:
# Package-Requires: ()
# Last-Updated:
#           By:
#     Update #: 0
# URL:
# Doc URL:
# Keywords:
# Compatibility:
#
#

# Commentary:
#
#
#
#

# Change Log:
#
#
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
#
#

# Code:


import ctypes
from ctypes import *
import numpy as np
from colorama import Fore, Style
import textwrap
import struct
import matplotlib.pyplot as plt
import os
import sys

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)
sys.path.append(current_dir)
so_file = current_dir + "/tangram/c_src/kacy16.so"
kacy16_cfunc = CDLL(so_file)

from args import config

def fp64d_to_fp16b(a):
    return bin(np.float16(a).view('H'))[2:].zfill(16)


def fp16b_to_fp16d(a):
    _float16_a = struct.pack("H", a)
    return np.frombuffer(_float16_a, dtype=np.float16)[0]


def bin_format(bin_num):
    return '_'.join(textwrap.wrap(bin_num[::-1], 4))[::-1]

# entrance

def kacy_fp16(chunk_a,
              chunk_b,
              psum):

    if config.debug is True:
        print(Fore.BLUE + "====================" + Style.RESET_ALL)
        print("[" + Fore.GREEN + "python" + Style.RESET_ALL + "]" +
              " _monkey_kacy" + Fore.RED + " fp16: \t" + Style.RESET_ALL)
        print("[" + Fore.GREEN + "python" +
              Style.RESET_ALL + "]", end=" ")
        for e in chunk_a:
            print(f"{e:<8.8f}", end=" |")
        print("\n[" + Fore.GREEN + "python" +
              Style.RESET_ALL + "]", end=" ")
        for e in chunk_b:
            print(f"{e:<8.8f}", end=" |")
        print("\n[" + Fore.GREEN + "python" +
              Style.RESET_ALL + "]", end=" ")
        print(f"{psum:<8.8f}")

    # specify the input format
    kacy16_cfunc.kacy_f16_main.argtypes = [ctypes.POINTER(ctypes.c_float),
                                           ctypes.POINTER(ctypes.c_float),
                                           ctypes.c_float,
                                           c_short,
                                           c_short,
                                           c_short,
                                           c_short]

    kacy16_cfunc.kacy_f16_main.restype = c_float

    chunk_a = np.ascontiguousarray(chunk_a.detach().numpy())
    chunk_b = np.ascontiguousarray(chunk_b.detach().numpy())

    assert(len(chunk_a) == len(chunk_b))

    res = kacy16_cfunc.kacy_f16_main(
        chunk_a.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
        chunk_b.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
        psum,
        len(chunk_a),
        config.tangram,
        config.pw,
        config.offset)

    if config.debug is True:
        res_r = chunk_a @ chunk_b + psum
        error = res - res_r
        if res_r != 0:
            err_per = round(error/res_r*100, 4)
            print("[" + Fore.GREEN + "python" + Style.RESET_ALL + "]" +
                  Fore.RED + " Kacy/Re/ERR/ERR(%): \t" + Style.RESET_ALL,
                  res, '/', res_r, '/', error, '/',
                  err_per, "%")

        # error guard. err_per is %
        if abs(res_r) > 0.1 and abs(err_per) > 0.5:
            print("kacy error went off")
            exit(-1)

    return res

def dump():
    kacy16_cfunc.da_dump()

if __name__ == '__main__':

    a = float(sys.argv[1])
    b = float(sys.argv[2])
    psum = float(sys.argv[3])

    kacy_fp16(a, b, psum)

#
# kacy.py ends here
