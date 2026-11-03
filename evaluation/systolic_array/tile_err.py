"""Output error of the RTL arrays on their DNN tiles: final running sum of every PE and tile vs the float64 reference."""
import sys, numpy as np
def f16(x): return x.astype(np.uint16).view(np.float16).astype(np.float64)
def finals(N, model, t, c, off, order, pre="fin"):
    off = off + (1 if t else 0)              # the registered-mode PE has one more pipeline stage
    d = np.load(f"stim/s{N}_{model}.npz"); ref, starts, lens = d["ref"], d["starts"], d["lens"]
    o = np.loadtxt(f"out/{pre}_N{N}_t{t}_c{c}_{model}.txt", dtype=np.int64)[:, 1:]
    v = f16(o)
    out = np.zeros_like(ref)
    ends = starts + lens
    for i in range(N):
        for j in range(N):
            k = i * N + j if order == 0 else j * N + i
            cyc = i + j + ends + off
            out[:, i, j] = v[np.minimum(cyc, len(v) - 1), k]
    return out, ref
def rel(out, ref):
    scale = np.abs(ref).reshape(ref.shape[0], -1).max(1)[:, None, None]   # per-tile output scale
    return np.abs(out - ref) / np.maximum(scale, 1e-6)
mode = sys.argv[1] if len(sys.argv) > 1 and __name__ == "__main__" else "none"
if mode == "cal":
    for order in (0, 1):
        for off in range(-2, 8):
            out, ref = finals(4, "resnet18", 0, 0, off, order)
            print(order, off, f"{np.median(rel(out, ref)):.2e}")
elif mode == "run":
    order, off = int(sys.argv[2]), int(sys.argv[3])
    for N in (4, 8):
        for m in ("resnet18", "mobilenet_v2", "resnet50", "vit_b_16"):
            row = [f"N={N} {m:13s}"]
            for t, c in ((0, 0), (2, 0), (2, 2)):
                out, ref = finals(N, m, t, c, off, order); e = rel(out, ref)
                row.append(f"t{t}c{c} mean {e.mean()*100:.3f}% p99 {np.quantile(e,.99)*100:.3f}% max {e.max()*100:.3f}%")
            s0, _ = finals(N, m, 0, 0, off, order); s2, _ = finals(N, m, 2, 0, off, order)
            sc = np.abs(ref).reshape(ref.shape[0], -1).max(1)[:, None, None]
            row.append(f"tfp-vs-std mean {(np.abs(s2-s0)/np.maximum(sc,1e-6)).mean()*100:.3f}% same {np.mean(s2==s0)*100:.1f}%")
            print(" | ".join(row))
