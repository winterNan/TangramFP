// kacy16_conv2d_cuda.cu --- 
// 
// Filename: kacy16_conv2d_cuda.cu
// Description: 
// Author: Yuan Yao <yuan.yao@it.uu.se>
// Maintainer: 
// Created: Thu Apr 25 14:35:19 2024 (+0200)
// Version: 
// Package-Requires: ()
// Last-Updated: 
//           By: 
//     Update #: 0

// Change Log:
// 
// 
// 
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
// 
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
// 
// 

// Code:

#include <torch/types.h>
#include "pytorch_cuda_helper.h"

template <typename T>
__global__ void kacy16_conv_im2col_gpu_kernel(
    const int n, const T *data_im, const int height,
    const int width, const int kernel_h, const int kernel_w, const int pad_h,
    const int pad_w, const int stride_h, const int stride_w,
    const int dilation_h, const int dilation_w,
    const int batch_size,
    const int num_channels, const int height_col,
    const int width_col, T *data_col)
{
    CUDA_1D_KERNEL_LOOP(index, n)
    {
        // index index of output matrix
        const int w_col = index % width_col;
        const int h_col = (index / width_col) % height_col;
        const int b_col = (index / width_col / height_col) % batch_size;
        const int c_im = (index / width_col / height_col) / batch_size;
        const int c_col = c_im * kernel_h * kernel_w;

        const int h_in = h_col * stride_h - pad_h;
        const int w_in = w_col * stride_w - pad_w;
        T *data_col_ptr =
            data_col +
            ((c_col * batch_size + b_col) * height_col + h_col) * width_col + w_col;
        const T *data_im_ptr =
            data_im + (b_col * num_channels + c_im) * height * width;

        for (int i = 0; i < kernel_h; ++i)
        {
            for (int j = 0; j < kernel_w; ++j)
            {
                T val = static_cast<T>(0);
                const int h_im = h_in + i * dilation_h;
                const int w_im = w_in + j * dilation_w;
                if (h_im > -1 && w_im > -1 && h_im < height && w_im < width)
                {
                    val = data_im_ptr[h_im * width + w_im];
                }
                *data_col_ptr = val;
                data_col_ptr += batch_size * height_col * width_col;
            }
        }
    }
}

void kacy16_conv_im2col_cuda(Tensor data_im,
                         const int channels, const int height,
                         const int width, const int ksize_h,
                         const int ksize_w, const int pad_h, const int pad_w,
                         const int stride_h, const int stride_w,
                         const int dilation_h, const int dilation_w,
                         const int parallel_imgs, Tensor data_col)
{
    int height_col =
        (height + 2 * pad_h - (dilation_h * (ksize_h - 1) + 1)) / stride_h + 1;
    int width_col =
        (width + 2 * pad_w - (dilation_w * (ksize_w - 1) + 1)) / stride_w + 1;
    int num_kernels = channels * height_col * width_col * parallel_imgs;

    AT_DISPATCH_FLOATING_TYPES_AND_HALF(
        data_im.scalar_type(), "kacy16_conv_im2col_gpu", [&]
        { kacy16_conv_im2col_gpu_kernel<scalar_t><<<GET_BLOCKS(num_kernels),
                                                THREADS_PER_BLOCK, 0,
                                                at::cuda::getCurrentCUDAStream()>>>(
              num_kernels, data_im.data_ptr<scalar_t>(),
              height, width, ksize_h, ksize_w,
              pad_h, pad_w, stride_h, stride_w, dilation_h, dilation_w,
              parallel_imgs, channels,
              height_col, width_col, data_col.data_ptr<scalar_t>()); });

    AT_CUDA_CHECK(cudaGetLastError());
}

// 
// kacy16_conv2d_cuda.cu ends here
