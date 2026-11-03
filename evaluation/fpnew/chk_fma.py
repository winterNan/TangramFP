# Compare netlist outputs with round-to-nearest-even FP16 a*b+c at the best-matching latency.
# usage: chk_fma.py <trace> <out.txt>   -> prints "latency=<k> mismatches=<n>/<total>"
import sys, numpy as np
def val(h):
    e, m = (h >> 10) & 31, h & 1023
    if e == 31: return None
    v = m * 2.0 ** -24 if e == 0 else (1024 + m) * 2.0 ** (e - 25)
    return -v if h >> 15 else v
def rne16(x): return int(np.float16(x).view(np.uint16))
tr = [list(map(int, l.split()[:3])) for l in open(sys.argv[1]) if l.strip()]
out = [list(map(int, l.split())) for l in open(sys.argv[2]) if l.strip()]
exp = []
for a, b, c in tr:
    va, vb, vc = val(a), val(b), val(c)
    exp.append(None if None in (va, vb, vc) else rne16(va * vb + vc))
best = None
for lat in range(0, 5):
    n = bad = 0
    for k, e in enumerate(exp):
        if e is None or k + lat >= len(out): continue
        n += 1; g = out[k + lat][1]
        if g != e and not ((g | e) & 0x7fff == 0): bad += 1
    if best is None or bad < best[1]: best = (lat, bad, n)
print(f"latency={best[0]} mismatches={best[1]}/{best[2]}")
