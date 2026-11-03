"""Llama-2-7B perplexity on WikiText-2 (test) with every weight and attention MAC through the TangramFP emulator.
Plain-PyTorch implementation of the reference model (Meta's consolidated checkpoint), so that every projection goes
through F.linear and the attention through F.scaled_dot_product_attention, both patched by tfp.patch_functional()."""
import argparse, json, math, time, os, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
import sentencepiece as spm
import tfp
from datasets import load_dataset

ap = argparse.ArgumentParser()
ap.add_argument("--ckpt", default=os.environ.get("LLAMA_CKPT", os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"), "llama-2-7b"))); ap.add_argument("--tok", default=os.environ.get("LLAMA_TOKENIZER", os.path.join(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"), "llama-2-7b", "tokenizer.model")))
ap.add_argument("--nseq", type=int, default=6); ap.add_argument("--len", type=int, default=128)
ap.add_argument("--cfgs", default="fp32,fp16,trunc,rte"); ap.add_argument("--offset", type=int, default=0)
ap.add_argument("--chunk", type=int, default=8); ap.add_argument("--thr2", type=int, default=12); ap.add_argument("--out", default="")
a = ap.parse_args()
tfp.set_thr2(a.thr2)

P = json.load(open(os.path.join(a.ckpt, "params.json")))
D, H, L, eps = P["dim"], P["n_heads"], P["n_layers"], P["norm_eps"]
hd = D // H
sd = torch.load(os.path.join(a.ckpt, "consolidated.00.pth"), map_location="cpu", mmap=True)
W = lambda k: sd[k].float()

class RMSNorm(nn.Module):
    def __init__(s, w): super().__init__(); s.w = w
    def forward(s, x): return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + eps) * s.w

def rope(T):
    f = 1.0 / (10000.0 ** (torch.arange(0, hd, 2).float() / hd))
    ang = torch.outer(torch.arange(T).float(), f)
    return torch.polar(torch.ones_like(ang), ang)                 # (T, hd/2)

def apply_rope(x, fc):                                           # x: (B, T, H, hd)
    xc = torch.view_as_complex(x.float().reshape(*x.shape[:-1], -1, 2))
    return torch.view_as_real(xc * fc[None, :, None, :]).flatten(3)

class Block(nn.Module):
    def __init__(s, i):
        super().__init__(); p = f"layers.{i}."
        s.wq, s.wk, s.wv, s.wo = (W(p + f"attention.{n}.weight") for n in ("wq", "wk", "wv", "wo"))
        s.w1, s.w2, s.w3 = (W(p + f"feed_forward.{n}.weight") for n in ("w1", "w2", "w3"))
        s.n1, s.n2 = RMSNorm(W(p + "attention_norm.weight")), RMSNorm(W(p + "ffn_norm.weight"))
    def forward(s, x, fc):
        B, T, _ = x.shape; h = s.n1(x)
        q, k, v = (F.linear(h, w).view(B, T, H, hd) for w in (s.wq, s.wk, s.wv))
        q, k = apply_rope(q, fc), apply_rope(k, fc)
        y = F.scaled_dot_product_attention(q.transpose(1, 2), k.transpose(1, 2), v.transpose(1, 2), is_causal=True)
        x = x + F.linear(y.transpose(1, 2).reshape(B, T, D), s.wo)
        h = s.n2(x)
        return x + F.linear(F.silu(F.linear(h, s.w1)) * F.linear(h, s.w3), s.w2)

t0 = time.time()
emb = W("tok_embeddings.weight"); blocks = [Block(i) for i in range(L)]
norm, out_w = RMSNorm(W("norm.weight")), W("output.weight")
print(f"loaded in {time.time() - t0:.0f} s", flush=True)

def model(ids):
    x = emb[ids][None]; fc = rope(len(ids))
    for b in blocks: x = b(x, fc)
    return F.linear(norm(x), out_w)[0]

sp = spm.SentencePieceProcessor(model_file=a.tok)
text = "\n\n".join(load_dataset("wikitext", "wikitext-2-raw-v1", split="test")["text"])
ids = torch.tensor([sp.bos_id()] + sp.encode(text[:400000]))
seqs = [ids[i * a.len:(i + 1) * a.len] for i in range(a.nseq)]

def mk(name):
    if name == "fpnew": return tfp.Cfg(mode="fp16", chunk=1, acc16=True)    # FPnew FP16 FMA: running sum rounded to FP16 after every MAC
    if name in ("fp32", "fp16"): return tfp.Cfg(mode=name, chunk=a.chunk)
    return tfp.Cfg(mode="tangram", chunk=a.chunk, offset=a.offset, ac=name.replace("+bd", ""), bd=int(name.endswith("+bd")))

res, nll_ref = {}, {}
for name in a.cfgs.split(","):
    cfg = mk(name); undo = tfp.patch_functional(cfg); t0 = time.time(); nll = []
    for s in seqs:
        with torch.no_grad():
            logits = model(s)
        nll.append(F.cross_entropy(logits[:-1].float(), s[1:], reduction="none"))
    undo(); nll = torch.cat(nll); nll_ref[name] = nll
    r = {"ppl": math.exp(nll.mean().item()), "tokens": len(nll), "sec": time.time() - t0}
    if cfg.mode != "fp32":
        st = cfg.stats.astype(float); r["macs"] = int(st.sum())
        r["mode_share"] = dict(zip(tfp.STAT_NAMES, (st / st.sum()).round(5).tolist()))
    for base in ("fp32", "fp16"):
        if base in nll_ref and base != name:
            r[f"mean_abs_dnll_{base}"] = (nll - nll_ref[base]).abs().mean().item()
    res[name] = r
    print("llama2-7b", name, json.dumps(r), flush=True)
    if a.out: json.dump({"args": vars(a), "results": res}, open(a.out, "w"), indent=1)
