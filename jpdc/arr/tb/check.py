"""Compare the running sums of an RTL array simulation with the float64 tile results.
Error of each output = |sum - exact| / sum_k |a_k w_k| (the magnitude scale of the dot product).
usage: check.py <N> <unused> <ref.npz> <rtl_out.txt> [stim.txt]"""
import sys, numpy as np
N = int(sys.argv[1]); R = np.load(sys.argv[3]); ref, starts, lens = R["ref"], R["starts"], R["lens"]
d = np.loadtxt(sys.argv[4], dtype=np.int64)[:, 1:].astype(np.uint16).view(np.float16).astype(np.float64)
st = np.loadtxt(sys.argv[5] if len(sys.argv) > 5 else sys.argv[3].replace(".npz", ".txt"), dtype=np.int64)
L = int(lens.sum())
A = np.array([st[i:i + L, i] for i in range(N)]).astype(np.uint16).view(np.float16).astype(np.float64)
W = np.array([st[j:j + L, N + j] for j in range(N)]).astype(np.uint16).view(np.float16).astype(np.float64)
errs = []
for t in range(len(ref)):
    s0, n = starts[t], lens[t]
    mag = np.abs(A[:, s0:s0 + n]) @ np.abs(W[:, s0:s0 + n]).T
    for i in range(N):
        for j in range(N):
            c = s0 + n - 1 + i + j
            win = d[c:c + 6, i * N + j]
            errs.append(np.abs(win - ref[t, i, j]).min() / max(mag[i, j], 1e-6))
errs = np.array(errs)
print(f"tiles {len(ref)}: error / sum|products|: median {np.median(errs):.2e}, 95% {np.quantile(errs, .95):.2e}, max {errs.max():.2e}")
