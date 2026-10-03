# Benchmark history

## Memory / arithmetic sanity

| Test | Result |
|---|---:|
| Max HBM allocation | 7 GiB PASS |
| D2D copy | 194.7 GB/s |
| Read | 326.6 GB/s |
| Write | 274.4 GB/s |
| Read+write aggregate | 405.5 GB/s |
| FP32 register sanity | 3.56 TFLOP/s |
| FP16 scalar/vector sanity | 4.64 TFLOP/s |
| Stability loop | 484,131 kernel launches / ~5 min |

The simple arithmetic kernels are not vendor-peak benchmarks.

## Custom tiled GEMM

| Precision | Sizes | Result |
|---|---|---:|
| FP32 | 1024² / 2048² / 4096² | ~0.9 TFLOP/s, correctness PASS |
| FP16 mul + FP32 accum | 1024² / 2048² / 4096² | ~1.2 TFLOP/s, correctness PASS |

Thermal cycle during GEMM:

- edge max 69 °C
- hotspot max 80 °C
- memory max 67 °C
- max PWM readback 108
- max RPM 1573
- max GPU clock 1614 MHz

The fan curve crossed from the quiet step to the next step once temperature exceeded the 75 °C threshold.

## LLM results

| Model | VRAM peak | Prompt / pp | Generation / tg |
|---|---:|---:|---:|
| Qwen2.5-3B Q4_K_M | ~2.60 GB | 151.7 tok/s first run; pp512 99.31 | 73.6 tok/s first run; tg128 73.11 |
| Qwen3-8B Q4_K_M | ~5.44 GB | 78.5 tok/s first run; pp512 39.93 | 40.8 tok/s first run; tg128 41.51 |
