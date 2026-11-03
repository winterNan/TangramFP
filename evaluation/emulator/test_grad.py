# gradients of the emulated layers against autograd in binary32
import sys, torch
sys.argv = ["x", "--cfg", "fp16", "--ntrain", "64", "--ntest", "10", "--epochs", "1"]
exec(open("train_cifar.py").read().split("log, t0, step")[0])
for S in (1.0, 256.0, 4096.0):
  for net in (CNN(), ViT()):
    x, y = Xtr[:8], Ytr[:8]; net.train()
    CFG.mode = "fp16"; l1 = F.cross_entropy(net(x), y); g1 = [t / S for t in torch.autograd.grad(l1 * S, list(net.parameters()))]
    CFG.mode = "fp32"; l2 = F.cross_entropy(net(x), y); g2 = torch.autograd.grad(l2, list(net.parameters()))
    num = sum(((u - v) ** 2).sum() for u, v in zip(g1, g2)).sqrt(); den = sum((v ** 2).sum() for v in g2).sqrt()
    print(S, type(net).__name__, "loss fp16-emu %.6f fp32 %.6f, relative gradient difference %.2e" % (l1.item(), l2.item(), (num / den).item()))
