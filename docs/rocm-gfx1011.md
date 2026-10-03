# ROCm / HIP on gfx1011

## TheRock SDK

The working isolated SDK was installed at:

```text
/opt/therock-gfx1011-10.0.0
```

Observed HIP runtime version:

```text
7.15.26333
```

`rocminfo` correctly identified the GPU as `gfx1011:xnack-` with 8 GB HBM. No `HSA_OVERRIDE_GFX_VERSION` was required.

The HIP device property API reported 18 multiprocessors while HSA/kernel inventory reported 36 CUs. This is consistent with WGP-style reporting: 18 WGPs = 36 CUs.

## Hidden hostcall failure

The first simple HIP vector-add built at low optimization failed with:

```text
Pcie atomics not enabled, hostcall not supported
AQL dispatch failed
hipErrorIllegalState (401)
```

The important finding was that the generated code object contained a `HiddenHostcallBuffer` kernel argument. ROCm CLR rejects this hostcall path when PCIe atomics are unavailable.

Compiler comparison:

- O0 default: `HiddenHostcallBuffer` present
- O0 buffered printf: present
- O2 default: absent
- O2 hostcall printf-kind: absent for the simple kernel

An optimized vector-add built with ordinary compute semantics (for example `-O2 -DNDEBUG -mprintf-kind=buffered`) launched successfully and passed correctness.

**Conclusion:** lack of PCIe atomics blocked the hidden hostcall path, not ordinary HIP compute in general.

## Compute sanity

- 256 MiB `hipMalloc`: PASS
- 7 GiB allocation: PASS
- 5-minute stability loop: 484,131 kernel launches
- no post-test PCIe/AER/GPU-reset errors

## rocBLAS / hipBLAS problem

The TheRock family SDK contained:

- rocBLAS 5.6.0
- hipBLAS 3.6.0

The supplied `librocblas.so.5.6` had a required runtime dependency on:

```text
libhipblaslt.so.1
```

but the gfx1011 family bundle did not include hipBLASLt. `llama.cpp` itself does not directly require hipBLASLt in the HIP backend; it links HIP + hipBLAS + rocBLAS. The breakage was therefore caused by the way rocBLAS had been built.

## Isolated rocBLAS fix

A second rocBLAS was built into:

```text
/opt/therock-gfx1011-llama/install
```

Key properties:

- target: `gfx1011`
- `BUILD_WITH_HIPBLASLT=OFF`
- Tensile still enabled
- gfx1011 Tensile kernels installed under `lib/rocblas/library/gfx1011`
- no `libhipblaslt.so` in `DT_NEEDED`

Validation:

- rocBLAS SGEMM 1024x1024: PASS, max error 0 for the selected deterministic test
- existing hipBLAS 3.6.0 against the isolated `librocblas.so.5`: PASS
- `llama.cpp` CMake discovery: PASS

See [`../patches/rocblas-no-hipblaslt/README.md`](../patches/rocblas-no-hipblaslt/README.md).
