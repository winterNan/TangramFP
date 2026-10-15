#!/bin/bash
# Accuracy runs for the JPDC revision in the paper's evaluation setting: group MAC of 8 (--chunk 8),
# Skip-BD/AC threshold thr1 = 5 + offset, Null mode for s >= thr2.
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=22
A="fp32,fp16,fp16@16,trunc,rte,msb+bd"
L="python3 eval_llm.py --model gpt2-large --nseq 6"
$L --thr2 12 --cfgs $A              --out $R/llm_g8_thr1-5_thr2-12.json
$L --thr2 11 --cfgs fp16,rte        --out $R/llm_g8_thr1-5_thr2-11.json
$L --thr2 13 --cfgs fp16,rte        --out $R/llm_g8_thr1-5_thr2-13.json
$L --thr2 12 --offset -3 --cfgs fp16,trunc,rte --out $R/llm_g8_thr1-2_thr2-12.json
for m in "resnet18 300 10" "vit_b_16 60 4" "mobilenet_v2 300 10" "resnet50 200 10"; do set -- $m
  python3 eval_img.py --model $1 --n $2 --bs $3 --thr2 12 --cfgs $A --out $R/img_g8_$1_thr1-5_thr2-12.json
done
for net in cnn vit; do for c in fp16 rte; do
  python3 train_cifar.py --net $net --cfg $c --epochs 3 --thr2 12 --out $R/train_g8_${net}_$c.json
done; done
for m in "resnet18 300 10" "vit_b_16 60 4" "mobilenet_v2 300 10" "resnet50 200 10"; do set -- $m
  python3 eval_img.py --model $1 --n $2 --bs $3 --thr2 11 --cfgs fp16,rte --out $R/img_g8_$1_thr1-5_thr2-11.json
  python3 eval_img.py --model $1 --n $2 --bs $3 --thr2 12 --offset -3 --cfgs fp16,trunc,rte --out $R/img_g8_$1_thr1-2_thr2-12.json
done
echo QUEUE_DONE
