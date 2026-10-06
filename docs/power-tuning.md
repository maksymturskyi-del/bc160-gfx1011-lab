# Power and clock tuning status

Status as of 2026-10-06: tuning is intentionally paused after exhausting the obvious runtime controls exposed by the current amdgpu stack.

## Stable prerequisite state

The current daily boot uses a UKI that keeps Intel i915 in the initramfs but leaves amdgpu out of early KMS/initramfs. On this host that restores the working ~4.7 s delay between PCI enumeration and amdgpu probe and avoids the early retrain/AER failure seen when amdgpu binds almost immediately.

Known-good runtime state before tuning:

- BC-160 at `0000:03:00.0`
- `D0`, `runtime_status=active`
- `power/control=on`
- `d3cold_allowed=0` when exported
- endpoint-side link readable as `16 GT/s x16`
- custom fan service active, idle floor around PWM 77-79 / ~680-700 RPM
- no new AER, retrain, reset, VM flush, or recovery errors

## Vulkan compute baseline

A local Vulkan compute workload on RADV/NAVI12 was used for repeatable measurements.

Representative stock result:

- ~5.11 TFLOPS
- ~99% GPU busy
- ~1610 MHz SCLK
- ~96-100 W average/peak observed power in the short steady-state runs
- correctness PASS

One earlier run experienced AER / device-lost / failed GPU recovery, but after a full cold power cycle the same workload passed 10 s and 30 s validation runs with a stable PCIe link and no new kernel errors. Do not run overlapping benchmark processes if one is already stuck in `D` state.

## Power-cap sweep

The driver reports:

- minimum cap: 140 W
- default cap: 175 W
- maximum cap: 175 W

Only 175, 150, and 140 W were therefore meaningful to test.

| Cap | Avg power | Max sampled | TFLOPS | Relative perf | TFLOPS/W | Avg SCLK | Hotspot max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 175 W | 96.17 W | 99 W | 5.104 | 100.00% | 0.05308 | 1609 MHz | 63 °C |
| 150 W | 99.63 W | 101 W | 5.110 | 100.11% | 0.05129 | 1610 MHz | 71 °C |
| 140 W | 102.43 W | 104 W | 5.111 | 100.13% | 0.04989 | 1611 MHz | 77 °C |

The power cap was not binding in this workload: even the 140 W cap remained far above the ~100 W draw. The rising temperature/power across sequential runs is best treated as run-order / thermal accumulation, not as a benefit or penalty caused by the cap.

Current recommendation: leave the stock 175 W cap unless a heavier workload proves that a lower cap actually binds.

## SCLK / undervolt audit

Runtime controls exposed by this card are limited:

- `pp_od_clk_voltage`: absent
- no separate soft-max SCLK control found
- `pp_dpm_sclk` exposes only 300 / 700 / 1650 MHz states
- attempting a manual DPM mask intended to cap at 700 MHz did not constrain the observed load clock; telemetry still showed ~1611 MHz, so the test was stopped immediately
- 300 MHz was not tested after the 700 MHz control failed
- MCLK was not modified
- stock `power_dpm_force_performance_level=auto` was restored and verified

No useful undervolt or underclock was validated through the standard sysfs interface.

## Deferred next step

If this is revisited, start with a read-only audit of advanced PowerPlay/SMU interfaces such as `pp_table`, `pp_features`, `pp_power_profile_mode`, any `gpu_od` nodes, and `amdgpu_pm_info`. Tools such as LACT/CoreCtrl/rocm-smi may be checked for capability, but no VBIOS flashing or permanent firmware modification should be attempted based on the current data.

For now the card remains on stock cap/clock behavior with the known-good boot, runtime-PM, and fan-control setup.
