# Check tfp16.c against the original kacy16.so on random groups.
import ctypes, numpy as np, sys, tfp
k = ctypes.CDLL(sys.argv[1])
fp = ctypes.POINTER(ctypes.c_float)
k.kacy_f16_main.argtypes = [fp, fp, ctypes.c_float] + [ctypes.c_short] * 4
k.kacy_f16_main.restype = ctypes.c_float
rng = np.random.default_rng(0); bad = 0; n = 20000
cfg = tfp.Cfg(chunk=8, ac="rte_orig")
for t in range(n):
    size = int(rng.integers(1, 9))
    sc = 10.0 ** rng.uniform(-2, 1)
    a = (rng.standard_normal(size) * sc * 10.0 ** rng.uniform(-1.5, 1.5, size)).astype(np.float32)
    b = (rng.standard_normal(size) * 10.0 ** rng.uniform(-1.5, 1.5, size)).astype(np.float32)
    if t % 7 == 0: a[rng.integers(size)] = 0
    # two groups: the second sees the first's sum, as in the PyTorch patch
    r1 = k.kacy_f16_main(a.ctypes.data_as(fp), b.ctypes.data_as(fp), 0.0, size, 0x10, 5, 0)
    a2, b2 = a[::-1].copy(), b[::-1].copy()
    r2 = k.kacy_f16_main(a2.ctypes.data_as(fp), b2.ctypes.data_as(fp), r1, size, 0x10, 5, 0)
    cfg.chunk = size
    m = tfp.matmul(np.concatenate([a, a2])[None], np.concatenate([b, b2])[None], cfg)[0, 0]
    if np.float32(r2) != m:
        bad += 1
        if bad < 5: print("MISMATCH", size, r2, m)
print(f"{n} random two-group dot products, mismatches: {bad}")
