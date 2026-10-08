# Gaming / Steam / Gamescope

Status as of 2026-10-08: the BC-160 has been validated as a render GPU for games while the Intel iGPU remains the compositor/display GPU.

## Working topology

The validated path is:

```text
Steam / Proton / game
        ↓
BC-160 (RADV NAVI12, 1002:7360)
        ↓
Gamescope
        ↓
Intel Iris Xe (8086:9a49, i915)
        ↓
HDMI-A-1
```

The key separation is:

- **game child:** `DRI_PRIME=pci-0000_03_00_0`
- **Gamescope:** explicitly prefers Intel with `--prefer-vk-device 8086:9a49`
- **physical display:** Intel `i915` on `HDMI-A-1`

Do not export `DRI_PRIME` globally to the desktop session.

Also avoid using an exclusive global selector such as:

```bash
MESA_VK_DEVICE_SELECT=1002:7360!
```

because hiding the Intel Vulkan device can break the cross-GPU compositor/output path.

## Recommended gaming profile

The current default helper profile is:

```text
game / nested resolution: 1920x1080
Gamescope output:         2560x1440
physical HDMI:            2560x1440
refresh override:         none
```

Current Gamescope command shape:

```bash
gamescope \
  --prefer-vk-device 8086:9a49 \
  -f \
  -w 1920 -h 1080 \
  -W 2560 -H 1440 \
  -- env DRI_PRIME=pci-0000_03_00_0 <game command>
```

No FSR, NIS, LSFG, or forced refresh rate is used in the default profile.

The helper also supports environment overrides for render/output size:

- `BC160_RENDER_WIDTH`
- `BC160_RENDER_HEIGHT`
- `BC160_OUTPUT_WIDTH`
- `BC160_OUTPUT_HEIGHT`

## Why 1080p render is preferred

The laptop-to-BC path is bottlenecked by the host/root PCIe link at Gen3 x2.

A raw RGBA8 frame is approximately:

- 1920x1080: ~8.3 MB
- 2560x1440: ~14.7 MB

So a 1440p frame is about 1.78x larger than a 1080p frame before considering synchronization and compositor overhead.

In practice, switching Warframe from 1440p render to 1080p render while keeping 1440p output produced:

- lower BC-160 temperature
- lower fan noise
- substantially fewer visible FPS dips
- gameplay mostly around 57-60 FPS in the sampled mission

This makes 1080p render -> 1440p output the current recommended profile for this Gen3 x2 eGPU setup.

## Warframe validation

A live Warframe session confirmed the full chain.

Observed command line:

```text
/usr/bin/gamescope --prefer-vk-device 8086:9a49 -f
-w 1920 -h 1080 -W 2560 -H 1440 --
env DRI_PRIME=pci-0000_03_00_0 ...
Proton - Experimental/proton ...
Warframe/Tools/Launcher.exe
```

Runtime checks confirmed:

- Gamescope selected Intel Iris Xe
- nested X display used by Warframe: 1920x1080
- Warframe `EE.cfg`: `Graphics.FullScreenSizeX=1920`, `Graphics.FullScreenSizeY=1080`
- Gamescope output request: 2560x1440
- physical output: `HDMI-A-1` on Intel i915 at 2560x1440
- Steam performance overlay during a ~137 s capture showed mission gameplay mostly ~57-60 FPS
- large FPS drops were associated with loading, not sustained gameplay
- remaining in-mission frametime spikes were short and did not show strong evidence of a persistent PCIe/compositor bottleneck

The capture was recorded at 2560x1440 60 FPS; the monitor can be run at a higher refresh independently of game render rate.

## Steam integration helpers

Local helper scripts were developed outside the repository:

- `~/.local/bin/bc160-game-launch`
- `~/.local/bin/play`

`bc160-game-launch` is the outer host-side wrapper that performs the BC health check, starts host Gamescope on Intel, and gives only the game child the BC `DRI_PRIME` environment.

The intended simple Steam integration is a persistent per-game Launch Option:

```text
bc160-game-launch %command%
```

Then the `play` TUI can simply discover installed games and ask the already-running Steam client to launch the selected AppID. This avoids trying to pass a new environment through `steam -applaunch` to an already-running client.

## Custom compatibility-tool experiment

A local compatibility tool named `BC-160 Proton` was also prototyped.

Steam successfully discovered the tool after adding the required `toolmanifest.vdf`, but the runtime design hit an architectural issue:

- Steam launches the compatibility tool inside Steam Linux Runtime 4
- the host `/usr/bin/gamescope` is not visible in that container namespace
- the wrapper therefore exited before Proton Experimental or the game started

The host Gamescope binary itself was verified separately and works correctly.

This path is currently deferred. A future implementation would need a proper host-launch bridge from the Steam runtime to the host Gamescope process.

## Known caveats

- `16 GT/s x16` reported at the BC endpoint is not the effective host bandwidth; the root path remains Gen3 x2.
- Do not infer a PCIe problem from every short FPS dip. Loading, shader/asset work, CPU spikes, and engine behavior can also produce frametime spikes.
- The current 1080p -> 1440p profile is optimized for smooth ~60 FPS gameplay, not for maximizing native-resolution image quality.
