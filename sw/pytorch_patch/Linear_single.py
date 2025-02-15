from tqdm import tqdm
import sys
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

def linear_single(module, input):
    name = type(module).__name__
    print(Fore.GREEN + name + "[Linear_single]" + Style.RESET_ALL)

    _max_dim = len(input.size())

    if _max_dim == 3:
        output = module(input)
        res2 = output.clone()
        res2 = res2.view(input.size(dim=0),
                         input.size(dim=1),
                         module.weight.size(dim=0))
        pbar = tqdm(total = input.size(0) *
                            input.size(1) *
                            input.size(2) *
                            module.weight.size(0))

        # if _dumpon == True:
        #     _collector.initLayer(name)
        for x in range(input.size(0)):
            for y in range(input.size(1)):
                for k in range(module.weight.size(0)):
                    pbar.update(input.size(2))
                    _chunksize = config.chunksize
                    _lsize = input.size(2)
                    if _chunksize > _lsize:
                        _chunksize = _lsize
                    for z in range(0, _lsize, _chunksize):
                        _end = z + _chunksize
                        if _end >= _lsize:
                            _end = _lsize
                        chunk_a = module.weight[k][z:_end]
                        chunk_b = input[x][y][z:_end]
                        _psum = float(res2[x][y][k])
                        if config.monkey == "ORI":
                            c = chunk_a @ chunk_b + _psum
                        elif config.monkey == "1_X_Y":
                            c = kacy_fp16(chunk_a, chunk_b, _psum)
                        else:
                            print("wrong kacy:", config.monkey)
                            exit(-1)
                        res2[x][y][k] = float(c)

                    #     if _dumpon == True:
                    #         _collector.sample(a, b, c, _psum)
                    # if _dumpon == True:
                    #     _collector.doneNeuron()
                    res2[x][y][k] += float(module.bias[k])
        return res2

    elif _max_dim == 2:
        output = module(input)
        res2 = output.clone()
        res2 = res2.view(input.size(dim=0),
                         module.weight.size(dim=0))
        pbar = tqdm(total = input.size(0) *
                            input.size(1) *
                            module.weight.size(0))
        # if _dumpon == True:
        #     _collector.initLayer(name)
        for x in range(input.size(0)):
            for k in range(module.weight.size(0)):
                pbar.update(input.size(1))
                _chunksize = config.chunksize
                _lsize = input.size(1)
                if _chunksize > _lsize:
                    _chunksize = _lsize
                for y in range(0, _lsize, _chunksize):
                    _end = y + _chunksize
                    if _end >= _lsize:
                        _end = _lsize
                    chunk_a = module.weight[k][y:_end]
                    chunk_b = input[x][y:_end]
                    _psum = float(res2[x][k])
                    if config.monkey == "ORI":
                        c = chunk_a @ chunk_b + _psum
                    elif config.monkey == "1_X_Y":
                        c = kacy_fp16(chunk_a, chunk_b, _psum)
                    else:
                        print("wrong kacy:", config.monkey)
                        exit(-1)
                    res2[x][k] = float(c)

                #     if _dumpon == True:
                #         _collector.sample(a, b, c, _psum)
                # if _dumpon == True:
                #     _collector.doneNeuron()
                res2[x][k] += float(module.bias[k])
        return res2
    else:
        from inspect import currentframe, getframeinfo
        frameinfo = getframeinfo(currentframe())
        print(frameinfo.filename, frameinfo.lineno)
        exit(-1)
