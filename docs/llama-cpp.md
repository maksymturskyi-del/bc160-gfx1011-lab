# llama.cpp on BC-160 / gfx1011

## Baseline build

Known working source revision:

```text
edd6e2bbdad5930899a93db8fa73c3b61c7b9bcc
```

Date used: 2026-10-03.

Environment layout:

```text
ROCm/HIP SDK:       /opt/therock-gfx1011-10.0.0
isolated rocBLAS:   /opt/therock-gfx1011-llama/install
```

Core CMake intent:

```text
GGML_HIP=ON
CMAKE_HIP_ARCHITECTURES=gfx1011
GGML_HIP_RCCL=OFF
```

Baseline tests also kept FlashAttention disabled. `HSA_OVERRIDE_GFX_VERSION` was not used.

At runtime the isolated rocBLAS prefix must take precedence over the original TheRock rocBLAS so that the loader does not pull in the missing hipBLASLt dependency.

A helper environment template is in [`../scripts/llama-env.sh`](../scripts/llama-env.sh).

## Qwen2.5-3B-Instruct Q4_K_M

- Official GGUF
- File size: `2,104,932,768` bytes (~1.95 GiB)
- SHA256: `626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d`
- 37/37 layers offloaded
- peak VRAM ~2.60 GB
- model-ready time ~1.8 s in that run
- prompt processing 151.7 tok/s
- generation 73.6 tok/s
- `pp512` 99.31 tok/s
- `tg128` 73.11 tok/s

## Qwen3-8B Q4_K_M

- File size: `5,027,783,488` bytes (4.68 GiB)
- 37/37 layers offloaded
- ROCm model buffer: 4,455.34 MiB
- CPU-mapped model buffer observed: 333.84 MiB
- peak VRAM ~5.44 GB
- model-ready time ~0.47 s from verbose timestamps
- first prompt processing: 78.5 tok/s
- first generation: 40.8 tok/s
- `llama-bench pp512`: 39.93 tok/s
- `llama-bench tg128`: 41.51 tok/s

Thermals stayed on the silent fan step:

- edge 54 °C max
- hotspot 65 °C max
- memory 53 °C max
- readback PWM ~77
- ~677–688 RPM
- max recorded clock 1.616 GHz
- max recorded board power 142 W

No new AER, VM fault, timeout, GPU reset, or link-drop errors were observed after the tests.
