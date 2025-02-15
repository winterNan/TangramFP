// kacy16_conv.cpp ---
//
// Filename: kacy16_conv.cpp
// Description:
// Author: Yuan Yao <yuan.yao@it.uu.se>
// Maintainer:
// Created: Wed Apr 24 13:45:18 2024 (+0200)
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

#include "pytorch_cpp_helper.h"

void kacy16_conv_im2col_cpu(Tensor data_im,
                            const int channels, const int height,
                            const int width, const int ksize_h,
                            const int ksize_w, const int pad_h, const int pad_w,
                            const int stride_h, const int stride_w,
                            const int dilation_h, const int dilation_w,
                            const int parallel_imgs, Tensor data_col);

void kacy16_conv_im2col_cuda(Tensor data_im,
                             const int channels, const int height,
                             const int width, const int ksize_h,
                             const int ksize_w, const int pad_h,
                             const int pad_w,
                             const int stride_h, const int stride_w,
                             const int dilation_h, const int dilation_w,
                             const int parallel_imgs, Tensor data_col);

void kacy16_conv_shape_check(at::Tensor input,
                             at::Tensor weight, int kH,
                             int kW, int dH, int dW, int padH, int padW,
                             int dilationH, int dilationW, int group)
{
    TORCH_CHECK(weight.ndimension() == 4,
                "4D weight tensor (nOutputPlane,nInputPlane,kH,kW) \
expected, \but got: %s",
                weight.ndimension());

    TORCH_CHECK(weight.is_contiguous(), "weight tensor has to be contiguous");

    TORCH_CHECK(kW > 0 && kH > 0,
                "kernel size should be greater than zero, \
but got kH: %d kW: %d",
                kH, kW);

    TORCH_CHECK((weight.size(2) == kH && weight.size(3) == kW),
                "kernel size should be consistent with weight, ",
                "but got kH: %d kW: %d weight.size(2): %d, weight.size(3): %d",
                kH, kW, weight.size(2), weight.size(3));

    TORCH_CHECK(dW > 0 && dH > 0,
                "stride should be greater than zero, but got dH: %d dW: %d", dH,
                dW);

    TORCH_CHECK(dilationW > 0 && dilationH > 0,
                "dilation should be greater than 0, \
but got dilationH: %d dilationW: %d",
                dilationH, dilationW);

    int ndim = input.ndimension();
    int dimf = 0;
    int dimh = 1;
    int dimw = 2;

    if (ndim == 4) {
            dimf++;
            dimh++;
            dimw++;
        }

    TORCH_CHECK(ndim == 3 || ndim == 4,
                "3D or 4D input tensor expected but got: %s", ndim);

    long nInputPlane = weight.size(1) * group;
    long inputHeight = input.size(dimh);
    long inputWidth = input.size(dimw);
    long nOutputPlane = weight.size(0);
    long outputHeight =
        (inputHeight + 2 * padH - (dilationH * (kH - 1) + 1)) / dH + 1;
    long outputWidth =
        (inputWidth + 2 * padW - (dilationW * (kW - 1) + 1)) / dW + 1;

    if (outputWidth < 1 || outputHeight < 1)
        AT_ERROR(
                 "Given input size: (%ld x %ld x %ld). "
                 "Calculated output size: (%ld x %ld x %ld). Output size is too small",
                 nInputPlane, inputHeight, inputWidth, nOutputPlane, outputHeight,
                 outputWidth);

    TORCH_CHECK(input.size(1) == nInputPlane,
                "invalid number of input planes, expected: %d, but got: %d",
                nInputPlane, input.size(1));

    TORCH_CHECK((inputHeight >= kH && inputWidth >= kW),
                "input image is smaller than kernel");
}

void kacy16_conv_forward(Tensor input, Tensor weight, Tensor bias,
                         Tensor output, Tensor columns,
                         int kW, int kH, int dW, int dH, int padW, int padH,
                         int dilationW, int dilationH, int group,
                         int im2col_step) {
    bool isCuda = false;
    if (input.device().is_cuda()) {
        CHECK_CUDA_INPUT(input);
        CHECK_CUDA_INPUT(weight);
        CHECK_CUDA_INPUT(bias);
        CHECK_CUDA_INPUT(output);
        CHECK_CUDA_INPUT(columns);
        isCuda = true;
    } else {
        CHECK_CPU_INPUT(input);
        CHECK_CPU_INPUT(weight);
        CHECK_CPU_INPUT(bias);
        CHECK_CPU_INPUT(output);
        CHECK_CPU_INPUT(columns);
    }

    kacy16_conv_shape_check(input, weight, kH, kW, dH, dW, padH,
                            padW, dilationH, dilationW, group);
    at::DeviceGuard guard(input.device());

    int batch = 1;
    if (input.ndimension() == 3) {
        // Force batch
        batch = 0;
        input.unsqueeze_(0);
    }

    long batchSize = input.size(0);
    long nInputPlane = input.size(1);
    long inputHeight = input.size(2);
    long inputWidth = input.size(3);

    long nOutputPlane = weight.size(0);

    long outputWidth =
        (inputWidth + 2 * padW - (dilationW * (kW - 1) + 1)) / dW + 1;
    long outputHeight =
        (inputHeight + 2 * padH - (dilationH * (kH - 1) + 1)) / dH + 1;

    output = output.view({batchSize / im2col_step, im2col_step, nOutputPlane,
            outputHeight, outputWidth});
    columns = at::zeros(
                        {nInputPlane * kW * kH, im2col_step * outputHeight * outputWidth},
                        input.options());

    input = input.view({batchSize / im2col_step, im2col_step, nInputPlane,
            inputHeight, inputWidth});

    Tensor output_buffer = at::zeros({batchSize / im2col_step, nOutputPlane,
            im2col_step * outputHeight, outputWidth},
        output.options());

    output_buffer = output_buffer.view(
                                       {output_buffer.size(0), group, output_buffer.size(1) / group,
                                        output_buffer.size(2), output_buffer.size(3)});

    for (int elt = 0; elt < batchSize / im2col_step; elt++) {
        if (isCuda) {
            kacy16_conv_im2col_cuda(input[elt], nInputPlane, inputHeight,
                                    inputWidth, kH, kW, padH, padW, dH, dW, dilationH,
                                    dilationW, im2col_step, columns);
        } else {
            kacy16_conv_im2col_cpu(input[elt], nInputPlane, inputHeight,
                                   inputWidth, kH, kW, padH, padW, dH, dW, dilationH,
                                   dilationW, im2col_step, columns);
        }


        columns = columns.view({group, columns.size(0) / group, columns.size(1)});
        weight = weight.view({group, weight.size(0) / group, weight.size(1),
                weight.size(2), weight.size(3)});

        for (int g = 0; g < group; g++) {
            output_buffer[elt][g] = output_buffer[elt][g]
                .flatten(1)
                .addmm_(weight[g].flatten(1), columns[g])
                .view_as(output_buffer[elt][g]);
        }
        columns =
            columns.view({columns.size(0) * columns.size(1), columns.size(2)});
        weight = weight.view({weight.size(0) * weight.size(1), weight.size(2),
                weight.size(3), weight.size(4)});
    }

    output_buffer = output_buffer.view(
                                       {output_buffer.size(0), output_buffer.size(1) * output_buffer.size(2),
                                        output_buffer.size(3), output_buffer.size(4)});

    output_buffer = output_buffer.view({batchSize / im2col_step, nOutputPlane,
            im2col_step, outputHeight, outputWidth});
    output_buffer.transpose_(1, 2);

    output.copy_(output_buffer);
    output = output.view({batchSize, nOutputPlane, outputHeight, outputWidth});

    bias = bias.view({1, bias.size(0), 1, 1});
    output.add_(bias);

    input = input.view({batchSize, nInputPlane, inputHeight, inputWidth});

    if (batch == 0) {
        output = output.view({nOutputPlane, outputHeight, outputWidth});
        input = input.view({nInputPlane, inputHeight, inputWidth});
    }
}

template <typename T>
void kacy16_conv_im2col_cpu_kernel(
                                   const int n, const T *data_im, const int height,
                                   const int width, const int kernel_h, const int kernel_w, const int pad_h,
                                   const int pad_w, const int stride_h, const int stride_w,
                                   const int dilation_h, const int dilation_w,
                                   const int batch_size,
                                   const int num_channels, const int height_col,
                                   const int width_col, T *data_col) {
    for (int index = 0; index < n; index++) {
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

        for (int i = 0; i < kernel_h; ++i) {
            for (int j = 0; j < kernel_w; ++j) {
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

void kacy16_conv_im2col_cpu(Tensor data_im,
                            const int channels, const int height,
                            const int width, const int ksize_h,
                            const int ksize_w, const int pad_h, const int pad_w,
                            const int stride_h, const int stride_w,
                            const int dilation_h, const int dilation_w,
                            const int parallel_imgs, Tensor data_col) {
    int height_col =
        (height + 2 * pad_h - (dilation_h * (ksize_h - 1) + 1)) / stride_h + 1;
    int width_col =
        (width + 2 * pad_w - (dilation_w * (ksize_w - 1) + 1)) / stride_w + 1;
    int num_kernels = channels * height_col * width_col * parallel_imgs;

    AT_DISPATCH_FLOATING_TYPES_AND_HALF(
        data_im.scalar_type(), "", [&] {
            kacy16_conv_im2col_cpu_kernel<scalar_t>(
            num_kernels, data_im.data_ptr<scalar_t>(),
            height, width, ksize_h, ksize_w,
            pad_h, pad_w, stride_h, stride_w, dilation_h, dilation_w,
            parallel_imgs, channels,
            height_col, width_col, data_col.data_ptr<scalar_t>());
        }
    );
}

PYBIND11_MODULE(kacy16_conv2d, m) {
    m.def("kacy16_conv_forward", kacy16_conv_forward, "kacy16_conv_forward",
          py::arg("input"), py::arg("weight"), py::arg("bias"),
          py::arg("output"), py::arg("columns"), py::arg("kW"),
          py::arg("kH"), py::arg("dW"), py::arg("dH"), py::arg("padW"),
          py::arg("padH"), py::arg("dilationW"), py::arg("dilationH"),
          py::arg("group"), py::arg("im2col_step"));
}

void kacy16_conv_im2col_cuda(Tensor data_im,
                             const int channels, const int height,
                             const int width, const int ksize_h,
                             const int ksize_w, const int pad_h,
                             const int pad_w,
                             const int stride_h, const int stride_w,
                             const int dilation_h, const int dilation_w,
                             const int parallel_imgs, Tensor data_col){}
//
// kacy16_conv.cpp ends here
