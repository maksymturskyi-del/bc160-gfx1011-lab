# HIP sanity result

- Device: BC-160 / gfx1011
- 256 MiB allocation: PASS
- Optimized vector add: PASS
- HiddenHostcallBuffer absent in working code object
- No `HSA_OVERRIDE_GFX_VERSION`
- 5-minute stability loop: 484,131 launches
- PCIe/runtime-PM remained stable
