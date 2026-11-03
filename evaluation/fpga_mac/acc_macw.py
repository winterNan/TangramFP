import sys, numpy as np
tr = np.loadtxt(sys.argv[1], dtype=np.int64)
f16 = lambda v: v.astype(np.uint16).view(np.float16).astype(np.float64)
a, b, c = f16(tr[:, 0]), f16(tr[:, 1]), f16(tr[:, 2])
exact = a * b + c
for fn in sys.argv[2:]:
    o = np.loadtxt(fn, dtype=np.int64); w = ((o[:, 0] << 16) | o[:, 1]).astype(np.uint32).view(np.float32).astype(np.float64)
    best = None
    for lag in range(0, 5):
        y = w[lag:lag + len(exact)]
        if len(y) < len(exact): continue
        e = np.abs(y - exact) / np.maximum(np.abs(exact), 1e-30)
        m = (np.abs(exact) > 0)
        r = (np.median(e[m]), np.quantile(e[m], .99), lag)
        if best is None or r[0] < best[0]: best = r
    print("%-12s lag %d  median rel err %.2e  99%% %.2e" % (fn, best[2], best[0], best[1]))
