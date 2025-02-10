// pytorch_cpp_helper.hpp ---
//
// Filename: pytorch_cpp_helper.hpp
// Description:
// Author: Yuan Yao <yuan.yao@it.uu.se>
// Maintainer:
// Created: Wed Apr 24 13:10:21 2024 (+0200)
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


#ifndef PYTORCH_CPP_HELPER
#define PYTORCH_CPP_HELPER
#include <torch/extension.h>

#include <vector>

using namespace at;

#define CHECK_CUDA(x)                                                          \
  TORCH_CHECK(x.device().is_cuda(), #x " must be a CUDA tensor")
#define CHECK_CPU(x)                                                           \
  TORCH_CHECK(!x.device().is_cuda(), #x " must be a CPU tensor")
#define CHECK_CONTIGUOUS(x)                                                    \
  TORCH_CHECK(x.is_contiguous(), #x " must be contiguous")
#define CHECK_CUDA_INPUT(x)                                                    \
  CHECK_CUDA(x);                                                               \
  CHECK_CONTIGUOUS(x)
#define CHECK_CPU_INPUT(x)                                                     \
  CHECK_CPU(x);                                                                \
  CHECK_CONTIGUOUS(x)

#endif

//
// pytorch_cpp_helper.hpp ends here
