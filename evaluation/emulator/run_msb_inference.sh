#!/bin/bash
# Fill the MSB cells of Table 6 (ResNet50, ViT-B/16, Llama2-7B), same settings as run_accuracy.sh;
# fp16 is rerun in each job as the deviation reference. The three jobs run in parallel.
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=8
python3 eval_img.py --model resnet50 --n 1000 --bs 10 --thr2 12 --cfgs fp16,msb+bd --out $R/img2_g8_resnet50_n1000_thr2-12_msb.json > $R/msb_resnet50.log 2>&1 &
python3 eval_img.py --model vit_b_16 --n 300 --bs 4 --thr2 12 --cfgs fp16,msb+bd --out $R/img2_g8_vit_b_16_n300_thr2-12_msb.json > $R/msb_vit.log 2>&1 &
python3 eval_llama.py --thr2 12 --cfgs fp16,msb+bd --out $R/llama_g8_thr1-5_thr2-12_msb.json > $R/msb_llama.log 2>&1 &
wait
echo DONE
