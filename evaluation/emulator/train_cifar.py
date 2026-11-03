"""CIFAR-10 training with every MAC of the forward AND backward pass through the TangramFP emulator.
One autograd Function (2-D matmul) carries all MACs: conv = unfold + matmul, linear = matmul,
attention = two matmuls.  Weight updates, normalization and activations stay in binary32."""
import argparse, json, math, os, pickle, time, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
import tfp

ap = argparse.ArgumentParser()
ap.add_argument("--net", default="cnn"); ap.add_argument("--cfg", default="fp32")
ap.add_argument("--epochs", type=int, default=3); ap.add_argument("--bs", type=int, default=64)
ap.add_argument("--ntrain", type=int, default=50000); ap.add_argument("--ntest", type=int, default=2000)
ap.add_argument("--offset", type=int, default=0); ap.add_argument("--lr", type=float, default=0.0)
ap.add_argument("--evals", type=int, default=4, help="evaluations per epoch"); ap.add_argument("--chunk", type=int, default=8); ap.add_argument("--thr2", type=int, default=12)
ap.add_argument("--scale", type=float, default=1024.0, help="initial loss scale (emulated runs)"); ap.add_argument("--out", default="")
a = ap.parse_args()
tfp.set_thr2(a.thr2)

def mk(name):
    if name == "fpnew": return tfp.Cfg(mode="fp16", chunk=1, acc16=True)    # FPnew FP16 FMA: running sum rounded to FP16 after every MAC
    if name in ("fp32", "fp16"): return tfp.Cfg(mode=name, chunk=a.chunk)
    return tfp.Cfg(mode="tangram", chunk=a.chunk, offset=a.offset, ac=name.replace("+bd", ""), bd=int(name.endswith("+bd")))
CFG = mk(a.cfg)

class EmuMM(torch.autograd.Function):
    """C = A @ B for 2-D A (M,K), B (K,N); products and gradients are computed by the emulator."""
    @staticmethod
    def forward(ctx, A, B):
        ctx.save_for_backward(A, B)
        return torch.from_numpy(tfp.matmul(A.numpy(), B.t().numpy(), CFG))
    @staticmethod
    def backward(ctx, g):
        A, B = ctx.saved_tensors
        gA = torch.from_numpy(tfp.matmul(g.numpy(), B.numpy(), CFG)) if ctx.needs_input_grad[0] else None       # g @ B^T
        gB = torch.from_numpy(tfp.matmul(A.t().numpy(), g.t().numpy(), CFG)) if ctx.needs_input_grad[1] else None  # A^T @ g
        return gA, gB

def mm(A, B):
    return A @ B if CFG.mode == "fp32" else EmuMM.apply(A, B)

class Conv(nn.Conv2d):
    def forward(self, x):
        if CFG.mode == "fp32": return super().forward(x)
        B, C, H, W = x.shape
        cols = F.unfold(x, self.kernel_size, padding=self.padding, stride=self.stride)          # (B, K, L)
        K, L = cols.shape[1], cols.shape[2]
        out = mm(self.weight.reshape(self.out_channels, K), cols.permute(1, 0, 2).reshape(K, B * L))
        Ho = (H + 2 * self.padding[0] - self.kernel_size[0]) // self.stride[0] + 1
        out = out.reshape(self.out_channels, B, Ho, L // Ho).permute(1, 0, 2, 3)
        return out if self.bias is None else out + self.bias.view(1, -1, 1, 1)

class Lin(nn.Linear):
    def forward(self, x):
        if CFG.mode == "fp32": return super().forward(x)
        shp = x.shape
        out = mm(x.reshape(-1, shp[-1]), self.weight.t()).reshape(*shp[:-1], self.out_features)
        return out if self.bias is None else out + self.bias

class Block(nn.Module):
    def __init__(s, i, o, stride):
        super().__init__()
        s.c1, s.b1 = Conv(i, o, 3, stride, 1, bias=False), nn.BatchNorm2d(o)
        s.c2, s.b2 = Conv(o, o, 3, 1, 1, bias=False), nn.BatchNorm2d(o)
        s.sc = None if stride == 1 and i == o else nn.Sequential(Conv(i, o, 1, stride, 0, bias=False), nn.BatchNorm2d(o))
    def forward(s, x):
        y = s.b2(s.c2(F.relu(s.b1(s.c1(x)))))
        return F.relu(y + (x if s.sc is None else s.sc(x)))

class CNN(nn.Module):                     # ResNet-8 for CIFAR
    def __init__(s):
        super().__init__()
        s.c, s.b = Conv(3, 16, 3, 1, 1, bias=False), nn.BatchNorm2d(16)
        s.l = nn.Sequential(Block(16, 16, 1), Block(16, 32, 2), Block(32, 64, 2)); s.fc = Lin(64, 10)
    def forward(s, x):
        return s.fc(F.adaptive_avg_pool2d(s.l(F.relu(s.b(s.c(x)))), 1).flatten(1))

class Attn(nn.Module):
    def __init__(s, d, h):
        super().__init__(); s.h, s.qkv, s.proj = h, Lin(d, 3 * d), Lin(d, d)
    def forward(s, x):
        B, T, D = x.shape; hd = D // s.h
        q, k, v = s.qkv(x).reshape(B, T, 3, s.h, hd).permute(2, 0, 3, 1, 4)                       # (B, h, T, hd)
        if CFG.mode == "fp32":
            y = torch.softmax(q @ k.transpose(-1, -2) / math.sqrt(hd), -1) @ v
        else:
            y = torch.stack([torch.stack([mm(torch.softmax(mm(q[b, i], k[b, i].t()) / math.sqrt(hd), -1), v[b, i])
                                          for i in range(s.h)]) for b in range(B)])
        return s.proj(y.transpose(1, 2).reshape(B, T, D))

class ViT(nn.Module):                     # patch 4, width 64, depth 4, 4 heads
    def __init__(s, d=64, depth=4, h=4):
        super().__init__()
        s.patch = Conv(3, d, 4, 4, 0); s.pos = nn.Parameter(torch.zeros(1, 64, d)); nn.init.trunc_normal_(s.pos, std=0.02)
        s.blocks = nn.ModuleList([nn.ModuleList([nn.LayerNorm(d), Attn(d, h), nn.LayerNorm(d), Lin(d, 2 * d), Lin(2 * d, d)]) for _ in range(depth)])
        s.norm, s.head = nn.LayerNorm(d), Lin(d, 10)
    def forward(s, x):
        x = s.patch(x).flatten(2).transpose(1, 2) + s.pos
        for n1, at, n2, f1, f2 in s.blocks:
            x = x + at(n1(x)); x = x + f2(F.gelu(f1(n2(x))))
        return s.head(s.norm(x).mean(1))

def load(root=os.environ.get("CIFAR10_DIR", os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"), "cifar-10-batches-py"))):
    def rd(f):
        d = pickle.load(open(os.path.join(root, f), "rb"), encoding="bytes")
        return d[b"data"].reshape(-1, 3, 32, 32).astype(np.float32) / 255.0, np.array(d[b"labels"])
    tr = [rd(f"data_batch_{i}") for i in range(1, 6)]; te = rd("test_batch")
    X = np.concatenate([t[0] for t in tr]); Y = np.concatenate([t[1] for t in tr])
    mean, std = X.mean((0, 2, 3), keepdims=True), X.std((0, 2, 3), keepdims=True)
    f = lambda v: torch.from_numpy((v - mean) / std)
    return f(X), torch.from_numpy(Y), f(te[0]), torch.from_numpy(te[1])

torch.manual_seed(0); np.random.seed(0)
Xtr, Ytr, Xte, Yte = load(); Xtr, Ytr, Xte, Yte = Xtr[:a.ntrain], Ytr[:a.ntrain], Xte[:a.ntest], Yte[:a.ntest]
model = CNN() if a.net == "cnn" else ViT()
steps = a.epochs * (len(Xtr) // a.bs)
if a.net == "cnn":
    opt = torch.optim.SGD(model.parameters(), lr=a.lr or 0.05, momentum=0.9, weight_decay=5e-4)
else:
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr or 1e-3, weight_decay=0.05)
sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=opt.param_groups[0]["lr"], total_steps=steps, pct_start=0.15)

def evaluate():
    model.eval(); c = 0
    with torch.no_grad():
        for i in range(0, len(Xte), 250): c += (model(Xte[i:i + 250]).argmax(1) == Yte[i:i + 250]).sum().item()
    model.train(); return c / len(Xte)

log, t0, step = [], time.time(), 0
S, clean = (1.0 if CFG.mode == "fp32" else a.scale), 0
g = torch.Generator().manual_seed(0)
every = max(1, (len(Xtr) // a.bs) // a.evals)
for ep in range(a.epochs):
    perm = torch.randperm(len(Xtr), generator=g); run = 0.0
    for i in range(len(Xtr) // a.bs):
        idx = perm[i * a.bs:(i + 1) * a.bs]; x = Xtr[idx]
        if torch.rand(1, generator=g).item() < 0.5: x = x.flip(3)
        loss = F.cross_entropy(model(x), Ytr[idx]); opt.zero_grad()
        # Loss scaling, as in mixed-precision training: FP16 gradients underflow otherwise.  The scale is
        # halved when an operand leaves the FP16 range and doubled after 200 clean steps.
        ovf0 = int(CFG.stats[5]); (loss * S).backward()
        if S != 1.0:
            for p in model.parameters(): p.grad.div_(S)
        if CFG.mode != "fp32":
            if int(CFG.stats[5]) > ovf0: S, clean = max(S / 2, 1.0), 0
            else:
                clean += 1
                if clean >= 200: S, clean = min(S * 2, 65536.0), 0
        opt.step(); sched.step()
        step += 1; run += loss.item()
        if not math.isfinite(loss.item()): print("non-finite loss"); break
        if (i + 1) % every == 0:
            acc = evaluate(); log.append({"step": step, "epoch": ep + (i + 1) / (len(Xtr) // a.bs), "loss": run / every, "acc": acc, "scale": S, "sec": time.time() - t0})
            print(a.net, a.cfg, json.dumps(log[-1]), flush=True); run = 0.0
res = {"args": vars(a), "log": log}
if CFG.mode != "fp32":
    st = CFG.stats.astype(float); res["macs"] = int(st.sum()); res["mode_share"] = dict(zip(tfp.STAT_NAMES, (st / st.sum()).round(5).tolist()))
print(a.net, a.cfg, "FINAL", json.dumps({k: v for k, v in res.items() if k != "log"}), flush=True)
if a.out: json.dump(res, open(a.out, "w"), indent=1)
