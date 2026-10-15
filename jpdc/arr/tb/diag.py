import sys, numpy as np
N = 4
net = np.loadtxt(sys.argv[1], dtype=np.int64)[:, 1:]; rtl = np.loadtxt(sys.argv[2], dtype=np.int64)[:, 1:]
st = np.loadtxt(sys.argv[3], dtype=np.int64)
f = lambda v: float(np.array([v], np.uint16).view(np.float16)[0])
m = net != rtl
print("mismatching entries per PE:", m.sum(0))
for pe in np.where(m.sum(0))[0][:2]:
    i, j = divmod(pe, N); c0 = np.where(m[:, pe])[0][0]
    print(f"PE({i},{j}) first mismatch at line {c0}")
    for c in range(c0 - 4, c0 + 2):
        # operands that entered row i / column j k cycles before reaching this PE
        print(f"  line {c}: net {f(net[c,pe]):+.6e} rtl {f(rtl[c,pe]):+.6e} | a(row in, c-j-2..) "
              + " ".join(f"{f(st[c - j - k, i]):+.3e}" for k in (1, 2, 3))
              + " | w " + " ".join(f"{f(st[c - i - k, N + j]):+.3e}" for k in (1, 2, 3))
              + f" | clr {st[c - j - 2, 2 * N + i]}")
