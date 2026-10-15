import sys, ctypes, numpy as np
sys.path.insert(0, "../../emu"); import tfp
lib = tfp._lib
# use the C mul_core through tfp_mul1: product value -> integer mantissa product
rng = np.random.default_rng(1)
for corr, (ac, bd) in enumerate([("trunc", 0), ("msb", 1), ("rte", 0)]):
    with open(f"vec{corr}.txt", "w") as f:
        for i in range(20000):
            u = 0x400 | int(rng.integers(1024)); v = 0x400 | int(rng.integers(1024))
            if i < 64: u = 0x400 | [0, 1023, 0x3E0 | 16, 0x3E0 | 15][i % 4]; v = 0x400 | [0, 1023, 0x3E0 | 16, 0x3E0 | 15][(i // 4) % 4]
            hm = int(rng.integers(3))                       # 0 Full, 1 Skip-BD, 2 AC
            a = np.float32(u / 1024.0); b = np.float32(v / 1024.0)
            p = tfp.mul1(a, b, [1, 2, 3][hm], 5, ac, bd)   # ST_FULL=1, ST_SKIPBD=2, ST_AC=3
            f.write(f"{u} {v} {hm} {int(round(p * (1 << 20)))}\n")
