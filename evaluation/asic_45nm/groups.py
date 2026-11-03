# Instance lists of the sequential groups of a flattened Nangate45 MACW netlist: stage-2 flip-flops (mode register
# stage), other flip-flops (stage 1 and output), isolation latches.  usage: groups.py <netlist> <outprefix>
import re, sys
txt = open(sys.argv[1]).read(); g = {"st2": [], "ff": [], "lat": []}
for cell, inst, body in re.findall(r"^\s*(DFF_X1|DLH_X1)\s+(\S+)\s*\((.*?)\);", txt, re.S | re.M):
    q = re.search(r"\.Q\(\\?([^ )]+)", body).group(1)
    if cell == "DLH_X1": g["lat"].append(inst)
    elif re.match(r"(g_two\.|a2|b2|c2|m2|exp_bn_inferred)", q): g["st2"].append(inst)
    else: g["ff"].append(inst)
for k, v in g.items(): open(f"{sys.argv[2]}_{k}.txt", "w").write(" ".join(v) + "\n")
print(sys.argv[1], {k: len(v) for k, v in g.items()})
