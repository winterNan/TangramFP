from tqdm import tqdm
import sys
from IPython.core import ultratb
from colorama import Fore, Back, Style
import torch
import torch.nn.functional as F
import sys
import os
sys.path.append(os.path.dirname(
    os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)))))
from kacy import kacy_fp16
from kacy import config

sys.excepthook = ultratb.FormattedTB(color_scheme='Linux', call_pdb=False)

def matmul(a, b):
    # print(Fore.GREEN + "matmul" + Style.RESET_ALL)

    assert len(a.size()) == len(b.size())
    res2 = torch.zeros(a.size(0), a.size(1), a.size(2), b.size(3),
                       dtype=torch.float64)

    # pbar = tqdm(total = a.size(0) * a.size(1))

    # if _dumpon == True:
    #     _collector.initLayer("MatMul")
    for i in range(a.size(0)): # 1
        for j in range(a.size(1)): # 32
            # pbar.update(1)
            for k in range(a.size(2)): # 5
                for m in range(b.size(3)): # 5
                    _lsize = a.size(3)
                    _chunksize = config.chunksize
                    if _chunksize > _lsize:
                        _chunksize = _lsize
                    for l in range(0, _lsize, _chunksize):
                        _end = l + _chunksize
                        if _end >= _lsize:
                            _end = _lsize
                        chunk_a = a[i,j,k,l:_end].to(torch.float32)
                        chunk_b = b[i,j,l:_end,m].to(torch.float32)
                        _psum = float(res2[i][j][k][m])
                        if config.monkey == "ORI":
                            c = chunk_a @ chunk_b + _psum
                        elif config.monkey == "1_X_Y":
                            c = kacy_fp16(chunk_a, chunk_b, _psum)
                        else:
                            print("wrong kacy:", config.monkey)
                            exit(-1)
                        res2[i][j][k][m] = float(c)

    return res2
