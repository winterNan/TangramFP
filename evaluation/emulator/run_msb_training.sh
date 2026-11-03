#!/bin/bash
# Fill the training cells of Table 6: truncation and MSB for ResNet-8 and the 4-layer ViT,
# same settings as run_accuracy.sh; two runs at a time.
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=12
for c in trunc msb+bd; do
  for net in cnn vit; do
    python3 train_cifar.py --net $net --cfg $c --epochs 8 --thr2 12 --out $R/train8_g8_${net}_$c.json > $R/train8_${net}_$c.log 2>&1 &
  done
  wait
done
echo DONE
