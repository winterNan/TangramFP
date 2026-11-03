#!/bin/bash
# Second round: Llama-2-7B, larger evaluation sets, longer training (group MAC of 8, thr1 = 5).
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=20
python3 eval_llama.py --thr2 12 --cfgs fp32,fp16,trunc,rte --out $R/llama_g8_thr1-5_thr2-12.json
python3 eval_llama.py --thr2 11 --cfgs rte --out $R/llama_g8_thr1-5_thr2-11.json
for m in "resnet18 1000 10 fp32,fp16,trunc,msb+bd,rte" "mobilenet_v2 1000 10 fp32,fp16,trunc,msb+bd,rte" "resnet50 1000 10 fp32,fp16,trunc,rte" "vit_b_16 300 4 fp32,fp16,trunc,rte"; do set -- $m
  python3 eval_img.py --model $1 --n $2 --bs $3 --thr2 12 --cfgs $4 --out $R/img2_g8_$1_n$2_thr2-12.json
done
for net in cnn vit; do for c in fp32 fp16 rte; do
  python3 train_cifar.py --net $net --cfg $c --epochs 8 --thr2 12 --out $R/train8_g8_${net}_$c.json
done; done
echo DONE
