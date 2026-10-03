# rocBLAS without hipBLASLt

The gfx1011 TheRock bundle used in this experiment shipped rocBLAS 5.6.0 whose `librocblas.so.5.6` had a required `DT_NEEDED` on `libhipblaslt.so.1`, but the gfx1011 family bundle did not contain hipBLASLt.

The workaround was to rebuild **matching rocBLAS** into an isolated prefix:

```text
/opt/therock-gfx1011-llama/install
```

with the functional equivalent of:

```text
GPU_TARGETS=gfx1011
BUILD_WITH_HIPBLASLT=OFF
BUILD_WITH_TENSILE=ON
Release
clients/tests/benchmarks/samples disabled where possible
```

Validation checklist:

1. `readelf -d librocblas.so` contains no `libhipblaslt.so` entry.
2. gfx1011 Tensile kernels exist under `lib/rocblas/library/gfx1011`.
3. rocBLAS SGEMM 1024x1024 correctness passes.
4. Existing hipBLAS 3.6.0 works when this isolated `librocblas.so.5` is first in the runtime loader path.
5. `llama.cpp` CMake resolves HIP + hipBLAS + rocBLAS from the combined SDK/prefix path.

The original TheRock SDK was left untouched.
