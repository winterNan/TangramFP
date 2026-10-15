"""ctypes front end of the batched TangramFP FP16 emulator (tfp16.c) and PyTorch layer patching."""
import ctypes, os
import numpy as np

_lib = ctypes.CDLL(os.path.join(os.path.dirname(os.path.abspath(__file__)), "libtfp16.so"))
_fp = ctypes.POINTER(ctypes.c_float)
_lib.tfp_matmul2.argtypes = [_fp, _fp, _fp] + [ctypes.c_int] * 10 + [ctypes.POINTER(ctypes.c_longlong)]
_lib.tfp_matmul2.restype = None
_lib.tfp_mul1.argtypes = [ctypes.c_float, ctypes.c_float] + [ctypes.c_int] * 4
_lib.tfp_mul1.restype = ctypes.c_float

def set_thr2(t):
    """Null mode for s >= t (default 11)."""
    _lib.tfp_set_thr2(int(t))


AC = {"trunc": 0, "rte_orig": 1, "rte": 2, "msb": 3}
STAT_NAMES = ["zero", "full", "skip_bd", "ac", "skip", "ovf"]


class Cfg:
    """mode: 'fp32' (native), 'fp16' (all products Full) or 'tangram'.
    acc16: round the running sum to FP16 after every group (False: binary32 accumulator)."""
    def __init__(self, mode="tangram", chunk=8, cut=5, offset=0, ac="rte", bd=0, acc16=False):
        self.mode, self.chunk, self.cut, self.offset, self.ac, self.bd = mode, chunk, cut, offset, ac, bd
        self.acc16 = acc16
        self.stats = np.zeros(6, dtype=np.int64)

    def name(self):
        return self.mode if self.mode != "tangram" else f"tangram[ac={self.ac},bd={self.bd},off={self.offset},g={self.chunk}]"


def matmul(W, Xt, cfg):
    """W: (M,K), Xt: (N,K) float32 -> (M,N): out[m,n] = sum_k W[m,k]*Xt[n,k]."""
    W = np.ascontiguousarray(W, dtype=np.float32); Xt = np.ascontiguousarray(Xt, dtype=np.float32)
    M, K = W.shape; N, K2 = Xt.shape
    assert K == K2
    out = np.empty((M, N), dtype=np.float32)
    _lib.tfp_matmul2(W.ctypes.data_as(_fp), Xt.ctypes.data_as(_fp), out.ctypes.data_as(_fp), M, K, N,
                    cfg.chunk, cfg.cut, cfg.offset, AC[cfg.ac], cfg.bd, int(cfg.mode == "fp16"), int(cfg.acc16),
                    cfg.stats.ctypes.data_as(ctypes.POINTER(ctypes.c_longlong)))
    return out


def mul1(a, b, mode, cut=5, ac="rte", bd=0):
    return _lib.tfp_mul1(a, b, mode, cut, AC[ac], bd)


# ---- PyTorch patching: Conv2d and Linear forward passes go through matmul() ----
def patch(model, cfg):
    import torch, torch.nn as nn, torch.nn.functional as F

    def conv_fwd(mod, x):
        B, C, H, Wd = x.shape
        g = mod.groups
        pad = mod.padding
        if isinstance(pad, str):
            raise NotImplementedError("string padding")
        cols = F.unfold(x, mod.kernel_size, dilation=mod.dilation, padding=pad, stride=mod.stride)  # (B, C*k*k, L)
        L = cols.shape[2]
        Ho = (H + 2 * pad[0] - mod.dilation[0] * (mod.kernel_size[0] - 1) - 1) // mod.stride[0] + 1
        Wo = (Wd + 2 * pad[1] - mod.dilation[1] * (mod.kernel_size[1] - 1) - 1) // mod.stride[1] + 1
        Kg = cols.shape[1] // g
        Og = mod.out_channels // g
        w = mod.weight.detach().reshape(g, Og, Kg).numpy()
        cols = cols.reshape(B, g, Kg, L).permute(1, 0, 3, 2).reshape(g, B * L, Kg).numpy()   # (g, B*L, Kg)
        out = np.empty((g, Og, B * L), dtype=np.float32)
        for gi in range(g):
            out[gi] = matmul(w[gi], cols[gi], cfg)
        out = torch.from_numpy(out).reshape(g, Og, B, L).permute(2, 0, 1, 3).reshape(B, mod.out_channels, Ho, Wo)
        if mod.bias is not None:
            out = out + mod.bias.detach().view(1, -1, 1, 1)
        return out

    def lin_fwd(mod, x):
        shp = x.shape
        out = matmul(mod.weight.detach().numpy(), x.detach().reshape(-1, shp[-1]).numpy(), cfg)  # (O, n)
        out = torch.from_numpy(out.T.copy()).reshape(*shp[:-1], mod.out_features)
        if mod.bias is not None:
            out = out + mod.bias.detach()
        return out

    n = 0
    if cfg.mode == "fp32":
        return 0
    for m in model.modules():
        if isinstance(m, nn.Conv2d):
            m.forward = conv_fwd.__get__(m); n += 1
        elif type(m) is nn.Linear or m.__class__.__name__ == "NonDynamicallyQuantizableLinear":
            m.forward = lin_fwd.__get__(m); n += 1
    return n


def patch_functional(cfg, attention=True):
    """Route every F.conv2d / F.linear (and, optionally, the two matmuls of scaled-dot-product
    attention) through the emulator.  Returns a function that undoes the patch."""
    import math, torch, torch.nn.functional as F
    o_conv, o_lin, o_sdpa = F.conv2d, F.linear, F.scaled_dot_product_attention
    if cfg.mode == "fp32":
        return lambda: None

    def conv2d(x, weight, bias=None, stride=1, padding=0, dilation=1, groups=1):
        t = lambda v: (v, v) if isinstance(v, int) else tuple(v)
        stride, padding, dilation = t(stride), t(padding), t(dilation)
        B, C, H, Wd = x.shape
        O, _, kh, kw = weight.shape
        cols = F.unfold(x.detach(), (kh, kw), dilation=dilation, padding=padding, stride=stride)
        L = cols.shape[2]
        Ho = (H + 2 * padding[0] - dilation[0] * (kh - 1) - 1) // stride[0] + 1
        Wo = (Wd + 2 * padding[1] - dilation[1] * (kw - 1) - 1) // stride[1] + 1
        g, Kg, Og = groups, cols.shape[1] // groups, O // groups
        w = weight.detach().reshape(g, Og, Kg).numpy()
        cols = cols.reshape(B, g, Kg, L).permute(1, 0, 3, 2).reshape(g, B * L, Kg).numpy()
        out = np.empty((g, Og, B * L), dtype=np.float32)
        for gi in range(g):
            out[gi] = matmul(w[gi], cols[gi], cfg)
        out = torch.from_numpy(out).reshape(g, Og, B, L).permute(2, 0, 1, 3).reshape(B, O, Ho, Wo)
        if bias is not None:
            out = out + bias.detach().view(1, -1, 1, 1)
        return out

    def linear(x, weight, bias=None):
        shp = x.shape
        out = matmul(weight.detach().numpy(), x.detach().reshape(-1, shp[-1]).numpy(), cfg)
        out = torch.from_numpy(np.ascontiguousarray(out.T)).reshape(*shp[:-1], weight.shape[0])
        if bias is not None:
            out = out + bias.detach()
        return out

    def sdpa(q, k, v, attn_mask=None, dropout_p=0.0, is_causal=False, **kw):
        shp = q.shape                                   # (..., L, d)
        L, S, d = q.shape[-2], k.shape[-2], q.shape[-1]
        qf, kf, vf = (t.detach().reshape(-1, t.shape[-2], t.shape[-1]).numpy() for t in (q, k, v))
        outs = []
        for i in range(qf.shape[0]):
            a = torch.from_numpy(matmul(qf[i], kf[i], cfg)) / math.sqrt(d)      # (L, S)
            if is_causal:
                a = a.masked_fill(torch.ones(L, S, dtype=torch.bool).triu(1), float("-inf"))
            if attn_mask is not None:
                m = attn_mask.reshape(-1, L, S)[i % attn_mask.reshape(-1, L, S).shape[0]]
                a = a.masked_fill(~m, float("-inf")) if m.dtype == torch.bool else a + m
            a = torch.softmax(a, dim=-1).numpy()
            outs.append(matmul(a, np.ascontiguousarray(vf[i].T), cfg))           # (L, dv)
        return torch.from_numpy(np.stack(outs)).reshape(*shp[:-2], L, v.shape[-1])

    F.conv2d, F.linear = conv2d, linear
    if attention:
        F.scaled_dot_product_attention = sdpa

    def undo():
        F.conv2d, F.linear, F.scaled_dot_product_attention = o_conv, o_lin, o_sdpa
    return undo
