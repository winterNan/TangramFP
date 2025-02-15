import sys
import multiprocessing
from functools import partial
from colorama import Fore, Style
import torch.nn.functional as F
from IPython.core import ultratb
import os
import sys
sys.path.append(os.path.dirname(
    os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)))))
from kacy import kacy_fp16
from kacy import dump
from args import config

sys.excepthook = ultratb.FormattedTB(color_scheme='Linux', call_pdb=False)


def _mul_(patch_num, _num_core, kernels_flat, inputunfold, res2):
    _size = int(len(inputunfold) / _num_core)
    _start = patch_num * _size
    _end = _start + _size

    for m_batch in range(_start, _end, 1):
        for i in range(kernels_flat.size(0)):
            for j in range(inputunfold.size(2)):
                _lsize = inputunfold.size(1)
                _chunksize = config.chunksize
                if _chunksize > _lsize:
                    _chunksize = _lsize
                for k in range(0, _lsize, _chunksize):
                    _cend = k + _chunksize
                    if _cend >= _lsize:
                        _cend = _lsize

                    chunk_a = kernels_flat[i,k:_cend]
                    chunk_b = inputunfold[m_batch,k:_cend, j]
                    _psum = float(res2[m_batch][i][j])

                    if config.monkey == "ORI":
                        c = chunk_a @ chunk_b + _psum
                    elif config.monkey == "1_X_Y":
                        c = kacy_fp16(chunk_a, chunk_b, _psum)
                    else:
                        print("wrong kacy:", config.monkey)
                        exit(-1)

                    res2[m_batch][i][j] = float(c)


def conv2d_multi(module, input):
    # print("The monkey hack goes here")
    name = type(module).__name__
    print(Fore.GREEN + name + "[conv2d_multi]" + Style.RESET_ALL)

    filt = module.weight.data
    bias = None
    if module.bias is not None:
        bias = module.bias.data
    batch_size = input.size(dim=0)
    inputunfold = F.unfold(input,
                           kernel_size=module.kernel_size,
                           padding=module.padding,
                           stride=module.stride)
    kernels_flat = filt.view(module.out_channels, -1)

    input = module(input)
    res2 = input.clone()
    res2 = res2.view(batch_size,
                     kernels_flat.size(0),
                     inputunfold.size(2))

    for m_batch in range(len(inputunfold)): # batch
        for i in range(kernels_flat.size(0)): # out channel
            for j in range(inputunfold.size(2)): # 'image' size
                res2[m_batch][i][j] = 0

    # Parallelism goes here
    print("batch size: ", len(inputunfold))
    print("worker num: ", config.ncore)
    # assert (len(inputunfold) % _num_core == 0)
    pool = multiprocessing.Pool(processes=config.ncore)
    mul = partial(_mul_,
                  _num_core=config.ncore,
                  kernels_flat=kernels_flat.detach(),
                  inputunfold=inputunfold.detach(),
                  res2=res2.detach())
    pool.map(mul, range(0, config.ncore))

    res2 = res2.view(input.size())
    if bias is not None:
        bias = bias.unsqueeze(1).unsqueeze(2)
        res2 += bias.unsqueeze(0)

    return res2
