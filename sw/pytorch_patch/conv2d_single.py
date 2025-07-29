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

from os.path import dirname, abspath
sys.path.append(dirname(dirname(abspath(__file__)))+"/src/")

def conv2d_single(module, input):
    name = type(module).__name__
    print(Fore.GREEN + name + "[conv2d_single]" + Style.RESET_ALL)

    groups = module.groups
    filt_slices = module.weight.data.split(int(module.weight.data.size(0) / groups), dim=0)
    input_slices = input.split(int(input.size(1) / groups), dim=1)

    bias = None
    if module.bias is not None:
        bias = module.bias.data
    batch_size = input.size(dim=0)
    inputunfold = F.unfold(input_slices[0],
                           kernel_size=module.kernel_size,
                           padding=module.padding,
                           stride=module.stride)
    kernels_flat = filt_slices[0].view(int(module.out_channels / groups), -1)

    input = module(input)
    res2 = input.clone()

    res2 = res2.view(batch_size,
                     kernels_flat.size(0) * groups,
                     inputunfold.size(2))
    res2 = res2.zero_()

    #for m_batch in range(len(inputunfold)): # batch
    #    for i in range(kernels_flat.size(0)): # out channel
    #        for j in range(inputunfold.size(2)): # 'image' size
    #            res2[m_batch][i][j] = 0
    res2_slices = res2.split(int(res2.size(1) / groups), dim=1)

    pbar = tqdm(total =
                groups * 
                len(inputunfold) *
                kernels_flat.size(0) *
                inputunfold.size(2) *
                inputunfold.size(1))

    # if config.dumpon == True:
    #     _collector.initLayer(name)

    for group in range(groups):                                                   
        filt = filt_slices[group]                                                 
                                                                                  
        inputunfold = F.unfold(input_slices[group],                               
                               kernel_size=module.kernel_size,                    
                               padding=module.padding,                            
                               dilation=module.dilation,                          
                               stride=module.stride)                              
        kernels_flat = filt.view(int(module.out_channels / groups), -1) 

        for m_batch in range(len(inputunfold)): # batch
            for i in range(kernels_flat.size(0)): # out channel
                for j in range(inputunfold.size(2)): # 'image' size
                    pbar.update(inputunfold.size(1))
                    _chunksize = config.chunksize
                    _lsize = inputunfold.size(1)
                    if _chunksize > _lsize:
                        _chunksize = _lsize

                    for k in range(0, _lsize, _chunksize): # kernel size

                        _end = k + _chunksize
                        if _end >= _lsize:
                            _end = _lsize

                        chunk_a = kernels_flat[i,k:_end]
                        chunk_b = inputunfold[m_batch,k:_end, j]
                        _psum = float(res2_slices[group][m_batch][i][j])

                        if config.monkey == "ORI":
                            c = chunk_a @ chunk_b + _psum
                        elif config.monkey == "1_X_Y":
                            c = kacy_fp16(chunk_a, chunk_b, _psum)
                        else:
                            print("wrong kacy:", config.monkey)
                            exit(-1)

                        res2_slices[group][m_batch][i][j] = float(c)

                    #     if config.dumpon == True:
                    #         _collector.sample(a, b, c, _psum)

                    # if config.dumpon == True:
                    #     _collector.doneNeuron()


        # for m_batch in range(len(inputunfold)): # batch
        #     for i in range(kernels_flat.size(0)): # out channel
        #         for j in range(inputunfold.size(2)): # 'image' size
        #             pbar.update(inputunfold.size(1))
        #             for k in range(inputunfold.size(1)): # kernel size
        #                 a = float(kernels_flat[i][k])
        #                 b = float(inputunfold[m_batch][k][j])
        #                 _psum = float(res2[m_batch][i][j])
        #                 if _kacy == "ORI":
        #                     c = a * b + _psum
        #                 elif _kacy == "1_X_Y":
        #                     c = kacy_fp16(a, b, _psum)
        #                 else:
        #                     print("wrong kacy:", _kacy)
        #                     exit(-1)
        #                 res2[m_batch][i][j] = float(c)
        #                 if _dumpon == True:
        #                     _collector.sample(a, b, c, _psum)
        #             if _dumpon == True:
        #                 _collector.doneNeuron()

    res2 = torch.cat(res2_slices, dim=1)
    res2 = res2.view(input.size())
    if bias is not None:
        bias = bias.unsqueeze(1).unsqueeze(2)
        res2 += bias.unsqueeze(0)

    return res2
