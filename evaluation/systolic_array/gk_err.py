"""Output error of the arrays on the full-K tiles: like tile_fix_err.py, using stim/f{N}_*.npz and out/<pre>_N*."""
import sys, numpy as np, tile_err
def finals(N, model, t, c, off=1, order=0, pre="gk"):
    off = off + (1 if t else 0)              # the registered-mode PE has one more pipeline stage
    d = np.load(f"stim/g{N}_{model}.npz"); ref, starts, lens = d["ref"], d["starts"], d["lens"]
    o = np.loadtxt(f"out/{pre}_N{N}_t{t}_c{c}_{model}.txt", dtype=np.int64)[:, 1:]
    v = tile_err.f16(o); out = np.zeros_like(ref); ends = starts + lens
    for i in range(N):
        for j in range(N):
            k = i * N + j if order == 0 else j * N + i
            cyc = i + j + ends + off
            out[:, i, j] = v[np.minimum(cyc, len(v) - 1), k]
    return out, ref
if __name__ == "__main__":
    N = int(sys.argv[1]); pre = sys.argv[2]
    for m in sys.argv[3:]:
        row = [f"{N} {pre} {m:13s}"]
        for t, c in ((0, 0), (2, 0), (2, 2)):
            try:
                out, ref = finals(N, m, t, c, pre=pre); e = tile_err.rel(out, ref)
                row.append(f"{e.mean()*100:.3f} {np.quantile(e,.99)*100:.2f} {e.max()*100:.2f}")
            except (FileNotFoundError, OSError): row.append("n/a")
        print(" | ".join(row))
