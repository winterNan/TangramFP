"""Append the mode (the MAC's own rule: s = e_c - e_ab, thr1 = 5, thr2 = 10; Null for a zero operand) to a trace."""
import sys, numpy as np
t = np.loadtxt(sys.argv[1], dtype=np.int64)
a, b, c = t[:, 0], t[:, 1], t[:, 2]
ea, eb, ec = (a >> 10) & 31, (b >> 10) & 31, (c >> 10) & 31
zero = (ea == 0) | (eb == 0) | ((a & 1023) == 0) | ((b & 1023) == 0)      # as the RTL: operands with a zero mantissa field count as zero
czero = (ec == 0) | ((c & 1023) == 0)
d = np.where(czero, -99, ec - (ea + eb - 15))
m = np.where(d <= 0, 0, np.where(d < 5, 1, np.where(d < 10, 2, 3)))
m = np.where(zero, 3, m)
np.savetxt(sys.argv[2], np.column_stack([a, b, c, m]), fmt="%d")
