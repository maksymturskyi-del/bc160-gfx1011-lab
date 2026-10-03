# GEMM sanity

Custom tiled HIP GEMM, not a peak vendor BLAS benchmark.

- FP32 1024² / 2048² / 4096²: ~0.9 TFLOP/s, correctness PASS
- FP16 multiply + FP32 accumulation: ~1.2 TFLOP/s, correctness PASS
- Max edge/hotspot/memory: 69/80/67 °C
- Fan curve reacted as designed
- No post-test PCIe/AER/GPU-reset errors
