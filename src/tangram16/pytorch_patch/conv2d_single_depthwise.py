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


def conv2d_single_depthwise(module, input):

    name = type(module).__name__
    print(Fore.GREEN + name + "[Conv2d_single_dep]" + Style.RESET_ALL)

    _dumpon = (os.environ.get('KACYDUMPON') == "Y")
    bsz, channels, h, w = input.shape
    k_channels, _, k_h, k_w = module.weight.shape
    dilation = module.dilation[0]
    padding = module.padding[0]
    stride = module.stride[0]

    assert h == w, 'Input tensor must be square'
    assert channels == k_channels, 'Number of input channels \
                                    and kernel channels must match'
    assert k_h == k_w, 'Kernel must be square'
    input_size = h
    kernel_size = k_h

    # Split the input tensor and weight tensor along the channel dimension
    input_splits = input.split(1, dim=1)
    weight_splits = module.weight.split(1, dim=0)

    output_splits = []
    for i in range(channels):
        # Unfold the input, input_unf.shape:
            # torch.Size([bsz, kernel_size*kernel_size, window_size])
        input_unf = F.unfold(input_splits[i],
                             weight_splits[i].shape[-2:],
                             dilation=dilation,
                             padding=padding,
                             stride=stride)

        # Perform depth-wise convolution
        # input_unf.transpose(1, 2) shape:
            # torch.Size([bsz, window_size, kernel_size*kernel_size])
        # weight_splits[i].view(weight_splits[i].shape[0], -1).t() shape:
            # torch.Size([kernel_size*kernel_size, 1])
        # out_unf.shape:
            # torch.Size([bsz, 1, window_size])

        kernels_flat = weight_splits[i].view(
            weight_splits[i].shape[0], -1
        ).t()
        input_unf = input_unf.transpose(1, 2)

        # out_unf = input_unf.matmul(kernels_flat).transpose(1, 2)

        pbar = tqdm(total =
                    input_unf.size(0) *
                    input_unf.size(1) *
                    input_unf.size(2)
                    )

        res2 = torch.zeros(input_unf.size(0),
                           input_unf.size(1),
                           1)

        # if _dumpon == True:
        #     _collector.initLayer(name)

        for i in range(input_unf.size(0)):
            for j in range(input_unf.size(1)):
                pbar.update(input_unf.size(2))
                _chunksize = config.chunksize
                _lsize = input_unf.size(2)
                if _chunksize > _lsize:
                    _chunksize = _lsize
                for k in range(0, _lsize, _chunksize):

                    _end = k + _chunksize
                    if _end >= _lsize:
                        _end = _lsize

                    chunk_a = kernels_flat[k:_end].flatten()
                    chunk_b = input_unf[i][j][k:_end]
                    _psum = float(res2[i][j][0])

                    if config.monkey == "ORI":
                        c = chunk_a @ chunk_b + _psum
                    elif config.monkey == "1_X_Y":
                        c = kacy_fp16(chunk_a, chunk_b, _psum)
                    else:
                        print("wrong kacy:", config.monkey)
                        exit(-1)

                    res2[i][j][0] = float(c)

                #     if config.dumpon == True:
                #         _collector.sample(a, b, c, _psum)
                # if config.dumpon == True:
                #     _collector.doneNeuron()

        res2 = res2.transpose(1,2)

        # If bias is not None, add bias
        if module.bias is not None:
            res2 += bias[i].view(1, -1, 1)

        # Fold the output tensor and add it to the list of output splits
        combined_out = F.fold(res2,
                              (input_size +
                                  (2 * padding) -
                                  (dilation * (kernel_size - 1)) - 1
                              ) // stride + 1, # round-down division
                              (1, 1)
                              )

        output_splits.append(combined_out)

    # Concatenate the output splits along the
    # channel dimension to get the final output
    return torch.cat(output_splits, dim=1)
