from setuptools import setup
from torch.utils import cpp_extension
import os

src_root = '/home/yuan/xormul/src/tangram/'
# cpp_src = ['c_src/kacy16_conv2d.cpp',
#            'c_src/kacy16_conv2d_cuda.cu']
cpp_src = ['c_src/kacy16_conv2d.cpp']
inc_path = ['include/']

if __name__ == '__main__':

    include_dirs = [os.path.join(src_root, inc) for inc in inc_path]
    cpp_path = [os.path.join(src_root, src) for src in cpp_src]

    setup(
        name='tangram',
        ext_modules=[
            cpp_extension.CppExtension(
                'kacy16_conv2d',
                cpp_path,
                include_dirs=include_dirs,
                extra_compile_args=['-O0', '-g'])
        ],
        cmdclass={'build_ext': cpp_extension.BuildExtension}
    )
