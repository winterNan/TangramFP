# libtfp16.so: batched TangramFP FP16 emulator (needs F16C and OpenMP)
libtfp16.so: tfp16.c
	gcc -O3 -march=native -mf16c -fopenmp -shared -fPIC tfp16.c -o libtfp16.so -lm
