# BC-160 gfx1011 Lab

Reproducible notes for running an **AMD BC-160 8 GB HBM2 (Navi12 / gfx1011)** as an external compute and gaming GPU on an **ASUS VivoBook X513EA (i5-1135G7)**, stabilizing PCIe/runtime power management, enabling ROCm/HIP compute and `llama.cpp` inference, and using the BC-160 for game rendering while Intel i915 handles Gamescope/HDMI output.

> **Current best LLM result**
>
> Qwen3-8B `Q4_K_M`, all **37/37 layers offloaded** to BC-160, peak VRAM about **5.44 GB**, `llama-bench` **pp512 39.93 tok/s** and **tg128 41.51 tok/s**. First CLI inference measured **78.5 tok/s prompt processing** and **40.8 tok/s generation**. Max observed hotspot during this run was **65 °C** at the quiet fan floor (~PWM 77 / ~680 RPM), with no new AER, VM fault, reset, timeout, or link-drop errors.

## Hardware

- Host: ASUS VivoBook X513EA
- CPU: Intel Core i5-1135G7 (Tiger Lake)
- Compute GPU: AMD BC-160 8 GB HBM2
- PCI ID: `1002:7360`
- GPU ISA: `gfx1011`
- External PCIe path: M.2 -> PCIe riser -> AMD switch -> BC-160
- Host/root link bottleneck: PCIe Gen3 x2 (`8.0 GT/s x2`)
- Switch downstream / endpoint side: up to PCIe Gen4 x16 (`16.0 GT/s x16` reported)
- External PSU: QUBE SFX 600 W 80+ Gold
- Laptop internal battery disconnected during this work
- Internal laptop panel absent; HDMI becomes usable once i915 is initialized

## Working software stack

- Minimal Arch Linux diagnostic SSD
- Kernel observed during inventory: `7.2.3-arch1-3`
- TheRock per-family ROCm/HIP SDK installed at `/opt/therock-gfx1011-10.0.0`
- HIP runtime reported `7.15.26333`
- Isolated rocBLAS build at `/opt/therock-gfx1011-llama/install`
- rocBLAS 5.6.0 rebuilt with `BUILD_WITH_HIPBLASLT=OFF`
- hipBLAS 3.6.0
- `llama.cpp` commit `edd6e2bbdad5930899a93db8fa73c3b61c7b9bcc` (2026-10-03)
- HIP target: `gfx1011`
- No `HSA_OVERRIDE_GFX_VERSION`
- Runtime-PM workaround enabled
- Custom fan curve enabled

## Why this needed work

The path from “PCIe device appears” to stable LLM inference had several independent blockers:

1. **Firmware policy:** with BC-160 powered at POST, firmware hid the Intel iGPU (`00:02.0`). Hidden `SaSetup` settings had to be changed from `Primary Display = Auto` to `IGFX`, and `Internal Graphics = Auto` to `Enabled`.
2. **Runtime PM / BOCO:** after successful initialization the card could fall into a broken D3cold/runtime-PM transition roughly 50 seconds later.
3. **HIP hostcall trap:** an unoptimized HIP test generated a `HiddenHostcallBuffer` and failed because PCIe atomics/hostcall were unavailable. Optimized ordinary compute without that hidden hostcall path worked.
4. **Cooling policy:** stock firmware targeted very high temperature and kept the fan extremely slow. A quiet custom curve was added.
5. **ROCm userspace dependency mismatch:** TheRock's rocBLAS build depended on `libhipblaslt.so.1`, while the gfx1011 family bundle did not ship hipBLASLt. Rebuilding rocBLAS without hipBLASLt fixed the `llama.cpp` loader path.
6. **Early amdgpu bind timing:** on the later Omarchy setup, including amdgpu in the early initramfs/KMS path reduced PCI-enumeration-to-probe delay from ~4.7 s to ~0.02 s and correlated with an early PCIe retrain/AER failure. A test UKI that retained i915 but excluded early amdgpu restored the ~4.7 s delay and successful initialization.

## PCIe topology

```text
00:1d.0  Intel Tiger Lake PCH PCIe Root Port #9 [8086:a0b0]
  └─ 01:00.0  AMD switch upstream   [1002:1478]
      └─ 02:00.0  AMD switch downstream [1002:1479]
          └─ 03:00.0  AMD BC-160 [1002:7360]
```

See [`docs/pcie-runtime-pm.md`](docs/pcie-runtime-pm.md).

## BIOS / hidden firmware settings

Decoded hidden `SaSetup` settings:

| Setting | Offset | Before | After |
|---|---:|---:|---:|
| Primary Display | `0x0BA` | Auto (`3`) | IGFX (`0`) |
| Internal Graphics | `0x0C0` | Auto (`2`) | Enabled (`1`) |

`SaSetup` GUID: `72C5E28C-7783-43A1-8767-FAD73FCCAFA4`, data size `0x427`.

A one-shot custom EDK II UEFI app modified only those two bytes, verified the full variable after writing, then chainloaded the normal systemd-boot EFI binary. Details and known hashes are in [`docs/bios-firmware.md`](docs/bios-firmware.md).

## Fan curve

Measured fan behavior:

| PWM | RPM | Subjective noise |
|---:|---:|---|
| 79 | ~767 | effectively silent |
| 95 | ~1260 | quiet |
| 126 | ~2054 | moderate |
| 192 | ~3466 | loud / server-like |

Current curve:

| Max temperature | Target PWM |
|---|---:|
| `< 75 °C` | 79 |
| `75–<80 °C` | 95 |
| `80–<85 °C` | 110 |
| `85–90 °C` | 126 |
| `> 90 °C` | 160 |

Polling: 5 s. Hysteresis: 2 °C. Spin-up boost: PWM 110 for ~2 s if tachometer reports zero.

See [`scripts/bc160-fan-curve.sh`](scripts/bc160-fan-curve.sh) and [`systemd/bc160-fan-curve.service`](systemd/bc160-fan-curve.service).

## Compute results

### HIP / memory sanity

- Maximum tested HBM allocation: **7 GiB PASS**
- D2D copy: **194.7 GB/s**
- Read: **326.6 GB/s**
- Write: **274.4 GB/s**
- Read + write aggregate: **405.5 GB/s**
- FP32 register sanity: **3.56 TFLOP/s**
- FP16 scalar/vector sanity: **4.64 TFLOP/s**
- 5-minute stability loop: **484,131 kernel launches**

### Custom tiled GEMM sanity

- FP32: ~**0.9 TFLOP/s**
- FP16 multiply + FP32 accumulate: ~**1.2 TFLOP/s**
- 1024² / 2048² / 4096² correctness: PASS

These are **not peak-performance benchmarks**; they are sanity tests from a simple custom kernel.

### Qwen2.5-3B-Instruct Q4_K_M

- Model size: ~1.95 GiB
- 37/37 layers offloaded
- Peak VRAM: ~2.60 GB
- Prompt processing: **151.7 tok/s**
- Generation: **73.6 tok/s**
- `llama-bench pp512`: **99.31 tok/s**
- `llama-bench tg128`: **73.11 tok/s**

### Qwen3-8B Q4_K_M

- File size: `5,027,783,488` bytes (4.68 GiB)
- 37/37 layers offloaded
- ROCm model buffer: `4,455.34 MiB`
- CPU-mapped model buffer observed: `333.84 MiB`
- Peak VRAM: ~5.44 GB
- Model-ready time from verbose timestamps: ~0.47 s
- First inference prompt processing: **78.5 tok/s**
- First inference generation: **40.8 tok/s**
- `llama-bench pp512`: **39.93 tok/s**
- `llama-bench tg128`: **41.51 tok/s**
- Max power observed: **142 W**
- Max edge / hotspot / memory: **54 / 65 / 53 °C**
- Fan remained at readback PWM ~77, ~677–688 RPM


## Gaming / display pipeline

The BC-160 is also validated as the render GPU for Steam/Proton games while the Intel iGPU remains the compositor/display GPU:

```text
Game / Proton
    ↓
BC-160 / RADV NAVI12
    ↓
Gamescope on Intel Iris Xe
    ↓
i915 / HDMI-A-1
```

Current recommended profile for this host is **1920×1080 game render → 2560×1440 Gamescope/HDMI output**. On Warframe this reduced temperature/noise and substantially reduced the small FPS dips seen with native 1440p rendering. See [`docs/gaming.md`](docs/gaming.md).

## Important caveats

- The root-port path is still **Gen3 x2**, even though downstream links can report Gen4 x16. Do not interpret `16 GT/s x16` at the endpoint as host-to-GPU effective bandwidth.
- BC-160/V520-family boards were designed around server airflow assumptions; stock fan behavior can be far too passive for standalone desktop use.
- The exact original PM workaround and UEFI patcher source files were created on the diagnostic machine. This repository documents the verified behavior and includes **reconstructed equivalents or implementation notes** where the original source was not available in this chat export.
- Do **not** flash a different VBIOS based only on this repository. The installed VBIOS looked internally consistent and was left untouched.

## Repository map

- [`docs/hardware.md`](docs/hardware.md) — hardware and topology
- [`docs/bios-firmware.md`](docs/bios-firmware.md) — firmware reverse engineering and SaSetup patch
- [`docs/pcie-runtime-pm.md`](docs/pcie-runtime-pm.md) — D3cold / BOCO failure and workaround
- [`docs/rocm-gfx1011.md`](docs/rocm-gfx1011.md) — HIP, hostcall, TheRock, rocBLAS workaround
- [`docs/llama-cpp.md`](docs/llama-cpp.md) — working llama.cpp build/runtime path
- [`docs/benchmarks.md`](docs/benchmarks.md) — benchmark history
- [`docs/power-tuning.md`](docs/power-tuning.md) — power-cap, SCLK, and undervolt tuning status
- [`docs/gaming.md`](docs/gaming.md) — Steam/Proton, Gamescope multi-GPU routing, gaming profile, and launcher notes
- [`results/`](results/) — concise result snapshots

## Status

As of 2026-10-08, the BC-160 has a documented known-good daily boot path: i915 remains early, amdgpu is left out of the initramfs and loads later, the runtime-PM workaround stays enabled, and the custom fan service waits for late hwmon availability. ROCm/LLM compute is working, and the card is also validated for Steam/Proton gaming with BC-160 rendering and Intel Gamescope/HDMI output. The current gaming sweet spot on this Gen3 x2 host path is 1080p render → 1440p output. Basic power-cap and SCLK tuning was tested; the current sysfs controls did not yield a useful undervolt/underclock path, so deeper PowerPlay/SMU tuning remains deferred.
