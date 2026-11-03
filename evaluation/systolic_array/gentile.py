"""Stimulus for the N x N output-stationary array: tiles of real DNN layers (A: N output positions x K, W: K x N
output channels, K consecutive terms of the reduction), streamed back to back and skewed per row/column.
usage: gentile.py <model> <N> <ntiles> <K> <out_stim> <out_ref.npz>"""
import sys, os, numpy as np, torch, torchvision, torch.nn.functional as F, torchvision.transforms as T

def h(x): return np.asarray(x, dtype=np.float32).astype(np.float16).view(np.uint16).astype(np.int64)

model, N, ntiles, K, out, ref = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6]
rng = np.random.default_rng(11)
ds = torchvision.datasets.ImageFolder(os.environ.get("IMAGENETTE_VAL", os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"), "imagenette2-320", "val")),
     T.Compose([T.Resize(256), T.CenterCrop(224), T.ToTensor(), T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])]))
x = torch.stack([ds[int(i)][0] for i in rng.permutation(len(ds))[:2]])
m = getattr(torchvision.models, model)(weights="DEFAULT").eval()
for p in m.parameters(): p.requires_grad_(True)          # keep nn.MultiheadAttention off its fused path
layers = []                                            # (W (O,K), X (P,K), MACs)
def hook(mod, inp, outp):
    xi = inp[0].detach()
    if isinstance(mod, torch.nn.Conv2d):
        g = mod.groups
        cols = F.unfold(xi, mod.kernel_size, dilation=mod.dilation, padding=mod.padding, stride=mod.stride)
        B, CK, L = cols.shape; Kg = CK // g
        cols = cols.reshape(B, g, Kg, L).permute(1, 0, 3, 2).reshape(g, B * L, Kg).numpy()
        wt = mod.weight.detach().reshape(g, mod.out_channels // g, Kg).numpy()
        for gi in range(min(g, 8)): layers.append((wt[gi], cols[gi], wt[gi].shape[0] * cols[gi].shape[0] * Kg * g / min(g, 8)))
    else:
        cols = xi.reshape(-1, xi.shape[-1]).numpy(); wt = mod.weight.detach().numpy()
        layers.append((wt, cols, wt.shape[0] * cols.shape[0] * wt.shape[1]))
for mod in m.modules():
    if isinstance(mod, (torch.nn.Conv2d, torch.nn.Linear)): mod.register_forward_hook(hook)
with torch.no_grad(): m(x)
# layer weight: MACs (default) or, with a 7th argument dp, the number of dot products (MACs / K): with the
# complete dot product streamed per tile, the latter makes each layer's share of stream cycles equal its share of MACs
p = np.array([l[2] / (l[0].shape[1] if len(sys.argv) > 7 and sys.argv[7] == "dp" else 1.0) for l in layers]); p = p / p.sum()
As, Ws = [], []
for t in range(ntiles):
    wt, cols, _ = layers[rng.choice(len(layers), p=p)]
    Kl = wt.shape[1]; kk = min(K, Kl); k0 = 0 if Kl <= K else int(rng.integers(0, Kl - K + 1))
    rows = rng.integers(0, cols.shape[0], N); chans = rng.integers(0, wt.shape[0], N)
    As.append(cols[rows, k0:k0 + kk].astype(np.float16).astype(np.float32))      # (N, kk)
    Ws.append(wt[chans, k0:k0 + kk].T.astype(np.float16).astype(np.float32))     # (kk, N)
lens = np.array([x.shape[1] for x in As]); starts = np.concatenate([[0], np.cumsum(lens)[:-1]])
refs = np.stack([x.astype(np.float64) @ y.astype(np.float64) for x, y in zip(As, Ws)])
np.savez(ref, ref=refs, starts=starts, lens=lens)
Aflat = np.concatenate(As, 1); Wflat = np.concatenate(Ws, 0).T                   # (N, L)
L = Aflat.shape[1]; cyc = L + 2 * N + 4
a_s = np.zeros((cyc, N), np.int64); w_s = np.zeros((cyc, N), np.int64); c_s = np.zeros((cyc, N), np.int64)
for i in range(N):
    a_s[i:i + L, i] = h(Aflat[i]); w_s[i:i + L, i] = h(Wflat[i])
    c_s[i + starts, i] = 1
    c_s[L + N + i, i] = 1                                 # final flag so that the last tile is closed as well
np.savetxt(out, np.hstack([a_s, w_s, c_s]), fmt="%d")
z = ((Aflat == 0)[:, None, :] | (Wflat == 0)[None, :, :]).mean()
print(f"{model}: {ntiles} tiles of {N}x(<={K})x{N}, mean length {lens.mean():.1f}, {cyc} cycles, zero-operand share {z:.3f}")
