#!/bin/bash
# Llama-2-7B: locate the source of the perplexity increase (Null threshold 13, Null disabled).
cd $(dirname $0); R=../results; export OMP_NUM_THREADS=8
python3 eval_llama.py --thr2 13 --cfgs fp16,rte --out $R/llama_g8_thr1-5_thr2-13.json
python3 eval_llama.py --thr2 99 --cfgs rte --out $R/llama_g8_thr1-5_thr2-99.json
echo DONE
