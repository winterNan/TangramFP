"""ImageNet-pretrained classifiers through the TangramFP emulator (Imagenette validation images)."""
import argparse, json, os, sys, time, numpy as np, torch, torchvision
import torchvision.transforms as T
import tfp

WNIDS = ["n01440764", "n02102040", "n02979186", "n03000684", "n03028079",
         "n03394916", "n03417042", "n03425413", "n03445777", "n03888257"]
IDX = [0, 217, 482, 491, 497, 566, 569, 571, 574, 701]   # ImageNet-1k indices of the Imagenette classes

ap = argparse.ArgumentParser()
ap.add_argument("--model", default="resnet18"); ap.add_argument("--n", type=int, default=200)
ap.add_argument("--bs", type=int, default=10); ap.add_argument("--data", default=os.environ.get("IMAGENETTE_VAL", os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"), "imagenette2-320", "val")))
ap.add_argument("--cfgs", default="fp32,fp16,trunc,rte_orig,rte,msb"); ap.add_argument("--chunk", type=int, default=8)
ap.add_argument("--offset", type=int, default=0); ap.add_argument("--thr2", type=int, default=11); ap.add_argument("--out", default="")
a = ap.parse_args()
tfp.set_thr2(a.thr2)

torch.manual_seed(0)
ds = torchvision.datasets.ImageFolder(a.data, T.Compose([T.Resize(256), T.CenterCrop(224), T.ToTensor(),
                                      T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])]))
assert ds.classes == WNIDS
sel = np.random.default_rng(0).permutation(len(ds))[:a.n]
model = getattr(torchvision.models, a.model)(weights="DEFAULT").eval()
for p in model.parameters(): p.requires_grad_(True)      # keeps nn.MultiheadAttention off its C++ fast path

def mk(name):
    if name == "fpnew": return tfp.Cfg(mode="fp16", chunk=1, acc16=True)    # FPnew FP16 FMA: running sum rounded to FP16 after every MAC
    acc16 = name.endswith("@16"); name = name.replace("@16", "")
    if name in ("fp32", "fp16"): return tfp.Cfg(mode=name, chunk=a.chunk, acc16=acc16)
    return tfp.Cfg(mode="tangram", chunk=a.chunk, offset=a.offset, ac=name.replace("+bd", ""), bd=int(name.endswith("+bd")), acc16=acc16)

res = {}
ref_logits = {}
for name in a.cfgs.split(","):
    cfg = mk(name); undo = tfp.patch_functional(cfg); t0 = time.time()
    top1 = top5 = 0; logits = []
    for i in range(0, len(sel), a.bs):
        xs, ys = zip(*[ds[j] for j in sel[i:i + a.bs]])
        out = model(torch.stack(xs)).detach()
        logits.append(out)
        tgt = torch.tensor([IDX[y] for y in ys])
        top1 += (out.argmax(1) == tgt).sum().item()
        top5 += (out.topk(5, 1).indices == tgt[:, None]).any(1).sum().item()
    undo(); logits = torch.cat(logits); ref_logits[name] = logits
    r = {"top1": top1 / len(sel), "top5": top5 / len(sel), "sec": time.time() - t0, "n": len(sel)}
    if cfg.mode != "fp32":
        s = cfg.stats.astype(float); r["macs"] = int(s.sum())
        r["mode_share"] = {k: v for k, v in zip(tfp.STAT_NAMES, (s / s.sum()).round(5).tolist())}
    for base in ("fp32", "fp16", "fp16@16"):
        if base in ref_logits and base != name:
            b = ref_logits[base]
            r[f"agree_{base}"] = (b.argmax(1) == logits.argmax(1)).float().mean().item()
            r[f"logit_relerr_{base}"] = ((logits - b).norm(dim=1) / b.norm(dim=1)).mean().item()
    res[name] = r
    print(a.model, name, json.dumps(r), flush=True)
if a.out:
    json.dump({"args": vars(a), "results": res}, open(a.out, "w"), indent=1)
