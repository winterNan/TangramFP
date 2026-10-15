"""Operand traces (a, b, c as FP16 bit patterns, one MAC per line) for the MAC power simulations.
  synthetic: gentrace.py syn <mode> <n> <out>      mode in full|skip_bd|ac|skip
  workload : gentrace.py net <model> <n> <out>     consecutive MACs of dot products sampled from all
             conv / linear layers of an ImageNet model on Imagenette images (FP16 running sum as c)"""
import sys, numpy as np

def h(x): return np.asarray(x, dtype=np.float32).astype(np.float16).view(np.uint16)

def syn(mode, n, rng):
    lo, hi = {"full": (-3, 0), "skip_bd": (1, 4), "ac": (5, 9), "skip": (10, 14)}[mode]   # e_c - e_ab
    out = []
    while len(out) < n:
        ea, eb = rng.integers(-6, 5, 2); d = rng.integers(lo, hi + 1)
        ec = ea + eb + d
        if not -13 <= ec <= 14: continue
        m = 1 + rng.integers(0, 1024, 3) / 1024.0
        s = rng.choice([-1.0, 1.0], 3)
        out.append((s[0] * m[0] * 2.0 ** ea, s[1] * m[1] * 2.0 ** eb, s[2] * m[2] * 2.0 ** ec))
    return np.array(out, dtype=np.float32)

def net(model, n, rng, run=64):
    import torch, torchvision, torch.nn.functional as F, torchvision.transforms as T, os
    ds = torchvision.datasets.ImageFolder(os.path.expanduser("~/TangramFP-jpdc/data/imagenette2-320/val"),
         T.Compose([T.Resize(256), T.CenterCrop(224), T.ToTensor(), T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])]))
    x = torch.stack([ds[int(i)][0] for i in rng.permutation(len(ds))[:2]])
    m = getattr(torchvision.models, model)(weights="DEFAULT").eval()
    layers = []            # (W (O,K), cols (N,K), number of MACs)
    def hook(mod, inp, out):
        xi = inp[0].detach()
        if isinstance(mod, torch.nn.Conv2d):
            g = mod.groups
            cols = F.unfold(xi, mod.kernel_size, dilation=mod.dilation, padding=mod.padding, stride=mod.stride)
            B, CK, L = cols.shape; Kg = CK // g
            cols = cols.reshape(B, g, Kg, L).permute(1, 0, 3, 2).reshape(g, B * L, Kg).numpy()
            w = mod.weight.detach().reshape(g, mod.out_channels // g, Kg).numpy()
            for gi in range(min(g, 8)): layers.append((w[gi], cols[gi], w[gi].shape[0] * cols[gi].shape[0] * Kg * (g / min(g, 8))))
        else:
            cols = xi.reshape(-1, xi.shape[-1]).numpy(); w = mod.weight.detach().numpy()
            layers.append((w, cols, w.shape[0] * cols.shape[0] * w.shape[1]))
    for mod in m.modules():
        if isinstance(mod, (torch.nn.Conv2d, torch.nn.Linear)): mod.register_forward_hook(hook)
    with torch.no_grad(): m(x)
    p = np.array([l[2] for l in layers], dtype=np.float64); p /= p.sum()      # sample layers by their MAC count
    out = []
    while len(out) < n:
        w, cols, _ = layers[rng.choice(len(layers), p=p)]
        wr = w[rng.integers(w.shape[0])].astype(np.float16).astype(np.float32)
        xr = cols[rng.integers(cols.shape[0])].astype(np.float16).astype(np.float32)
        K = len(wr); k0 = 0 if K <= run else int(rng.integers(0, K - run + 1))
        ps = np.concatenate([[0.0], np.cumsum((wr * xr).astype(np.float32), dtype=np.float32)])   # running sum before each MAC
        for k in range(k0, min(K, k0 + run)): out.append((wr[k], xr[k], ps[k]))
    return np.array(out[:n], dtype=np.float32)

if __name__ == "__main__":
    kind, what, n, outp = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    rng = np.random.default_rng(7)
    t = syn(what, n, rng) if kind == "syn" else net(what, n, rng)
    t = np.clip(t, -65000, 65000)
    np.savetxt(outp, np.stack([h(t[:, 0]), h(t[:, 1]), h(t[:, 2])], 1), fmt="%d")
    # mode mix according to the MAC's own rule (s = e_c - e_ab, thr1 = 5, thr2 = 10), for the record
    a, b, c = (h(t[:, i]).astype(int) for i in range(3))
    ea, eb, ec = (a >> 10) & 31, (b >> 10) & 31, (c >> 10) & 31
    zero = ((a & 0x7FFF) == 0) | ((b & 0x7FFF) == 0) | (ea == 0) | (eb == 0)
    d = np.where(ec == 0, -99, ec - (ea + eb - 15))
    mix = {"zero": zero.mean(), "full": (~zero & (d <= 0)).mean(), "skip_bd": (~zero & (d > 0) & (d < 5)).mean(),
           "ac": (~zero & (d >= 5) & (d < 10)).mean(), "skip": (~zero & (d >= 10)).mean()}
    print(outp, {k: round(float(v), 4) for k, v in mix.items()})
