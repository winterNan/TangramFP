"""GPT-2 perplexity on WikiText-2 (test) with every weight and attention MAC through the TangramFP emulator."""
import argparse, json, math, time, numpy as np, torch, torch.nn.functional as F
import tfp
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers.pytorch_utils import Conv1D
from datasets import load_dataset

ap = argparse.ArgumentParser()
ap.add_argument("--model", default="gpt2-large"); ap.add_argument("--nseq", type=int, default=8)
ap.add_argument("--len", type=int, default=128); ap.add_argument("--cfgs", default="fp32,fp16,trunc,msb+bd,rte")
ap.add_argument("--offset", type=int, default=0); ap.add_argument("--chunk", type=int, default=8); ap.add_argument("--thr2", type=int, default=11); ap.add_argument("--out", default="")
a = ap.parse_args()
tfp.set_thr2(a.thr2)

tok = AutoTokenizer.from_pretrained(a.model)
model = AutoModelForCausalLM.from_pretrained(a.model, attn_implementation="sdpa").eval()
Conv1D.forward = lambda self, x: F.linear(x, self.weight.t(), self.bias)      # same computation, routed through F.linear
text = "\n\n".join(load_dataset("wikitext", "wikitext-2-raw-v1", split="test")["text"])
ids = tok(text, return_tensors="pt").input_ids[0]
seqs = [ids[i * a.len:(i + 1) * a.len] for i in range(a.nseq)]

def mk(name):
    acc16 = name.endswith("@16"); name = name.replace("@16", "")
    if name in ("fp32", "fp16"): return tfp.Cfg(mode=name, chunk=a.chunk, acc16=acc16)
    return tfp.Cfg(mode="tangram", chunk=a.chunk, offset=a.offset, ac=name.replace("+bd", ""), bd=int(name.endswith("+bd")), acc16=acc16)

res, nll_ref = {}, {}
for name in a.cfgs.split(","):
    cfg = mk(name); undo = tfp.patch_functional(cfg); t0 = time.time(); nll = []
    for s in seqs:
        with torch.no_grad():
            logits = model(s[None]).logits[0]
        nll.append(F.cross_entropy(logits[:-1].float(), s[1:], reduction="none"))
    undo(); nll = torch.cat(nll); nll_ref[name] = nll
    r = {"ppl": math.exp(nll.mean().item()), "tokens": len(nll), "sec": time.time() - t0}
    if cfg.mode != "fp32":
        st = cfg.stats.astype(float); r["macs"] = int(st.sum())
        r["mode_share"] = dict(zip(tfp.STAT_NAMES, (st / st.sum()).round(5).tolist()))
    for base in ("fp32", "fp16", "fp16@16"):
        if base in nll_ref and base != name:
            r[f"mean_abs_dnll_{base}"] = (nll - nll_ref[base]).abs().mean().item()
    res[name] = r
    print(a.model, f"off={a.offset}", name, json.dumps(r), flush=True)
if a.out: json.dump({"args": vars(a), "results": res}, open(a.out, "w"), indent=1)
