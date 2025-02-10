// common_cuda_helper.hpp ---
//
// Filename: common_cuda_helper.hpp
// Description:
// Author: Yuan Yao <yuan.yao@it.uu.se>
// Maintainer:
// Created: Wed Apr 24 13:25:31 2024 (+0200)
// Version:
// Package-Requires: ()
// Last-Updated:
//           By:
//     Update #: 0
// URL:
// Doc URL:
// Keywords:
// Compatibility:
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

#ifndef COMMON_CUDA_HELPER
#define COMMON_CUDA_HELPER

#include <cuda.h>

#define CUDA_1D_KERNEL_LOOP(i, n)                                   \
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < (n);    \
         i += blockDim.x * gridDim.x)

#define CUDA_2D_KERNEL_LOOP(i, n, j, m)                                 \
    for (size_t i = blockIdx.x * blockDim.x + threadIdx.x; i < (n);     \
         i += blockDim.x * gridDim.x)                                   \
        for (size_t j = blockIdx.y * blockDim.y + threadIdx.y; j < (m); \
             j += blockDim.y * gridDim.y)

#define CUDA_2D_KERNEL_BLOCK_LOOP(i, n, j, m)                   \
    for (size_t i = blockIdx.x; i < (n); i += gridDim.x)        \
        for (size_t j = blockIdx.y; j < (m); j += gridDim.y)

#define THREADS_PER_BLOCK 512

inline int GET_BLOCKS(const int N, const int num_threads = THREADS_PER_BLOCK) {
    int optimal_block_num = (N + num_threads - 1) / num_threads;
    int max_block_num = 4096;
    return min(optimal_block_num, max_block_num);
}

template <typename T>
__device__ T bilinear_interpolate(const T* input, const int height,
                                  const int width, T y, T x,
                                  const int index /* index for debug only*/) {
    // deal with cases that inverse elements are out of feature map boundary
    if (y < -1.0 || y > height || x < -1.0 || x > width) return 0;

    if (y <= 0) y = 0;
    if (x <= 0) x = 0;

    int y_low = (int)y;
    int x_low = (int)x;
    int y_high;
    int x_high;

    if (y_low >= height - 1) {
        y_high = y_low = height - 1;
        y = (T)y_low;
    } else {
        y_high = y_low + 1;
    }

    if (x_low >= width - 1) {
        x_high = x_low = width - 1;
        x = (T)x_low;
    } else {
        x_high = x_low + 1;
    }

    T ly = y - y_low;
    T lx = x - x_low;
    T hy = 1. - ly, hx = 1. - lx;
    // do bilinear interpolation
    T v1 = input[y_low * width + x_low];
    T v2 = input[y_low * width + x_high];
    T v3 = input[y_high * width + x_low];
    T v4 = input[y_high * width + x_high];
    T w1 = hy * hx, w2 = hy * lx, w3 = ly * hx, w4 = ly * lx;

    T val = (w1 * v1 + w2 * v2 + w3 * v3 + w4 * v4);

    return val;
}

template <typename T>
__device__ void bilinear_interpolate_gradient(const int height, const int width,
                                              T y, T x, T& w1, T& w2, T& w3, T& w4,
                                              int& x_low, int& x_high, int& y_low, int& y_high,
                                              const int index /* index for debug only*/) {
    // deal with cases that inverse elements are out of feature map boundary
    if (y < -1.0 || y > height || x < -1.0 || x > width) {
        // empty
        w1 = w2 = w3 = w4 = 0.;
        x_low = x_high = y_low = y_high = -1;
        return;
    }

    if (y <= 0) y = 0;
    if (x <= 0) x = 0;

    y_low = (int)y;
    x_low = (int)x;

    if (y_low >= height - 1) {
        y_high = y_low = height - 1;
        y = (T)y_low;
    } else {
        y_high = y_low + 1;
    }

    if (x_low >= width - 1) {
        x_high = x_low = width - 1;
        x = (T)x_low;
    } else {
        x_high = x_low + 1;
    }

    T ly = y - y_low;
    T lx = x - x_low;
    T hy = 1. - ly, hx = 1. - lx;

    // reference in forward
    // T v1 = input[y_low * width + x_low];
    // T v2 = input[y_low * width + x_high];
    // T v3 = input[y_high * width + x_low];
    // T v4 = input[y_high * width + x_high];
    // T val = (w1 * v1 + w2 * v2 + w3 * v3 + w4 * v4);

    w1 = hy * hx, w2 = hy * lx, w3 = ly * hx, w4 = ly * lx;

    return;
}

#endif

//
// common_cuda_helper.hpp ends here
