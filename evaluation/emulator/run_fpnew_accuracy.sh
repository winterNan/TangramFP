#!/bin/bash
# FPnew accuracy rows for Table 6: chain of FP16 fused MACs (cfg fpnew = fp16 products, chunk 1, running sum
# rounded to FP16 after every MAC), with the FP16 reference rerun in the same process. Samples as in Table 6.
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=6
python3 eval_img.py --model resnet50 --n 1000 --bs 10 --thr2 12 --cfgs fp16,fpnew --out $R/img2_g8_resnet50_n1000_fpnew.json > $R/fpnew_resnet50.log 2>&1 &
python3 eval_img.py --model vit_b_16 --n 300 --bs 4 --thr2 12 --cfgs fp16,fpnew --out $R/img2_g8_vit_b_16_n300_fpnew.json > $R/fpnew_vit.log 2>&1 &
python3 eval_llama.py --thr2 12 --cfgs fp16,fpnew --out $R/llama_g8_fpnew.json > $R/fpnew_llama.log 2>&1 &
(
python3 eval_img.py --model resnet18 --n 1000 --bs 10 --thr2 12 --cfgs fp16,fpnew --out $R/img2_g8_resnet18_n1000_fpnew.json > $R/fpnew_resnet18.log 2>&1
python3 eval_img.py --model mobilenet_v2 --n 1000 --bs 10 --thr2 12 --cfgs fp16,fpnew --out $R/img2_g8_mobilenet_v2_n1000_fpnew.json > $R/fpnew_mobilenet.log 2>&1
python3 eval_llm.py --model gpt2-large --nseq 6 --thr2 12 --cfgs fp16,fpnew --out $R/llm_g8_fpnew.json > $R/fpnew_gpt2.log 2>&1
for net in cnn vit; do
  python3 train_cifar.py --net $net --cfg fpnew --epochs 8 --thr2 12 --out $R/train8_g8_${net}_fpnew.json > $R/train8_${net}_fpnew.log 2>&1
done
) &
wait
echo DONE
