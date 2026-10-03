# Hardware

## Host

- ASUS VivoBook X513EA
- Intel Core i5-1135G7
- Internal panel absent
- Internal battery disconnected during testing
- Diagnostic OS on external USB SSD

## eGPU / compute device

- AMD BC-160
- PCI ID `1002:7360`
- Navi12 / `gfx1011`
- 8 GB HBM2
- Two PCIe 8-pin power inputs
- External PSU: QUBE SFX 600 W 80+ Gold

## PCIe topology

```text
00:1d.0 Intel RP9 [8086:a0b0]
01:00.0 AMD switch upstream [1002:1478]
02:00.0 AMD switch downstream [1002:1479]
03:00.0 BC-160 [1002:7360]
```

The host/root side negotiates `8.0 GT/s x2` (PCIe Gen3 x2). Downstream switch/card links can negotiate `16.0 GT/s x16` (PCIe Gen4 x16). Effective host transfer is therefore limited by the root-port x2 path.

## Power and riser notes

The riser and GPU were powered externally. The laptop battery was disconnected, which simplified power-state diagnosis. A dedicated runtime-PM workaround is still required because the amdgpu/BOCO path could otherwise return the PCIe device to runtime autosuspend/D3cold behavior.
