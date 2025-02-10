from tqdm import tqdm
import sys
import multiprocessing
from functools import partial
from IPython.core import ultratb
from colorama import Fore, Back, Style
import torch
import torch.nn.functional as F
import os
import sys
sys.path.append(os.path.dirname(
    os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)))))
from kacy import kacy_fp16
from args import config

sys.excepthook = ultratb.FormattedTB(color_scheme='Linux', call_pdb=False)

def _mul_3(patch_num, _num_core, input, weight, bias, res2):

    _size = int(input.size(0) / _num_core)
    _start = patch_num * _size
    _end = _start + _size

    for m_batch in range(_start, _end, 1):
        for y in range(input.size(1)):
            for k in range(weight.size(0)):
                for z in range(input.size(2)):
                    #TODO: go for group mac
                    a = float(weight[k][z])
                    b = float(input[m_batch][y][z])
                    _psum = float(res2[m_batch][y][k])
                    if config.monkey == "ORI":
                        c = a * b + _psum
                    elif config.monkey == "1_X_Y":
                        c = kacy_fp16(a, b, _psum)
                    else:
                        print("wrong kacy:", config.monkey)
                        exit(-1)
                    res2[m_batch][y][k] = float(c)
                res2[m_batch][y][k] += float(bias[k])


def _mul_2(patch_num, _num_core, input, weight, bias, res2):

    _size = int(input.size(0) / _num_core)
    _start = patch_num * _size
    _end = _start + _size

    for m_batch in range(_start, _end, 1):
        for k in range(weight.size(0)):
            for y in range(input.size(1)):
                #TODO go for group machine
                a = float(weight[k][y])
                b = float(input[m_batch][y])
                _psum = float(res2[m_batch][k])
                if config.monkey == "ORI":
                    c = a * b + _psum
                elif _kacy == "1_X_Y":
                    c = kacy_fp16(a, b, config.monkey)
                else:
                    print("wrong kacy:", config.monkey)
                    exit(-1)
                res2[m_batch][k] = float(c)
            res2[m_batch][k] += float(bias[k])


def linear_multi(module, input):
    name = type(module).__name__
    print(Fore.GREEN + name + "[Linear_multi]" + Style.RESET_ALL)
    _max_dim = len(input.size())
    if _max_dim == 3:

        output = module(input)
        res2 = output.clone()
        res2 = res2.view(input.size(dim=0),
                         input.size(dim=1),
                         module.weight.size(dim=0))
        # Parallelism goes here
        _num_core = int(os.environ.get('KACYNUMWORKER'))
        print(len(input))
        pool = multiprocessing.Pool(processes=_num_core)
        mul = partial(_mul_3,
                      _num_core=_num_core,
                      input = input.detach(),
                      weight = module.weight.detach(),
                      bias = module.bias.detach(),
                      res2 = res2.detach())
        pool.map(mul, range(0, _num_core))
        return res2

    elif _max_dim == 2:

        output = module(input)
        res2 = output.clone()
        res2 = res2.view(input.size(dim=0),
                         module.weight.size(dim=0))
        # Parallelism goes here
        _num_core = int(os.environ.get('KACYNUMWORKER'))
        print(len(input))
        pool = multiprocessing.Pool(processes=_num_core)
        mul = partial(_mul_2,
                      _num_core=_num_core,
                      input = input.detach(),
                      weight = module.weight.detach(),
                      bias = module.bias.detach(),
                      res2 = res2.detach())
        pool.map(mul, range(0, _num_core))
        return res2

    else:
        from inspect import currentframe, getframeinfo
        frameinfo = getframeinfo(currentframe())
        print(frameinfo.filename, frameinfo.lineno)
        exit(-1)
