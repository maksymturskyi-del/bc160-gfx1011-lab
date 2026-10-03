# BIOS / firmware work

## Original failure

With the BC-160 powered during POST, the Intel iGPU (`00:02.0 [8086:9a49]`) disappeared before Linux driver binding. The BC-160 became the firmware-selected graphics device even though it had no usable display connectors for this laptop, so HDMI output was lost.

When the BC-160 was absent at POST, the Intel iGPU enumerated normally and HDMI worked after i915 loaded. Hot-add was not a solution because firmware also removed/disabled the relevant root port when no external GPU was present at POST.

## SPI dump

A full 16 MiB SPI dump was read **read-only** via Linux MTD devices.

- Full dump SHA256: `657323b19ecd4b93c65a971d59ec4e42a632c2ba923f8a8d059e5f8176bba47e`

No SPI write was used for the fix.

## Hidden settings found through IFR/NVRAM analysis

`SaSetup` GUID:

`72C5E28C-7783-43A1-8767-FAD73FCCAFA4`

Variable size: `0x427` bytes.

Relevant offsets:

| Setting | Offset | Options | Before | After |
|---|---:|---|---:|---:|
| Primary Display | `0x0BA` | IGFX=0, PEG=1, PCH PCI=2, Auto=3, HG=4 | 3 | 0 |
| Internal Graphics | `0x0C0` | Disabled=0, Enabled=1, Auto=2 | 2 | 1 |

Other settings observed:

- Skip Scanning External Gfx: `SaSetup 0x1DD = 0`
- RP9 enable: `PchSetup 0x101 = 1`
- RP9 type: `0x2F9 = Slot 1`
- RP9 hotplug: `0x221 = 0`
- RP9 detect timeout: `0x319 = 0 ms`

## One-shot UEFI patcher

Linux efivarfs did not expose the `SaSetup` variable, so a small X64 EDK II UEFI application was used as a temporary fallback bootloader.

Workflow:

1. Keep canonical systemd-boot intact.
2. Temporarily place the custom app at `EFI/BOOT/BOOTX64.EFI`.
3. Create/check a one-shot marker to prevent repeated writes.
4. Locate exact `SaSetup` variable by GUID + name.
5. Verify expected size `0x427`, attributes, and old bytes (`03` at `0x0BA`, `02` at `0x0C0`).
6. Modify only those two bytes.
7. Write the full UEFI variable with `SetVariable`.
8. Re-read and verify the complete payload.
9. Confirm exactly two bytes changed.
10. Chainload canonical systemd-boot.

Patcher SHA256:

`9ac91fc5a2ac4981ac1dd52643ad945f5e6fbe333e0bdbba39373e4998db14ca`

After the patch, a cold boot with BC-160 powered enumerated both the Intel iGPU and the BC-160. HDMI worked through the Intel GPU and the BC-160 remained available as a compute device.

## VBIOS inventory (read-only)

No VBIOS flashing was performed.

PCI ROM capture:

- Size: 102,912 bytes
- SHA256: `b3f8d94b5bd97105f8119935fb02860231da1778ef009efaa994b9e5e8a8b502`
- Two valid images: legacy 58,368 bytes + EFI 44,544 bytes

ACPI VFCT copy:

- Size: 58,368 bytes
- SHA256: `da37c489ce01d5cfdc25952f63a9d3539a57ed406a365f0e49de980482fcdb9a`

The VFCT copy differed from the PCI legacy image by four bytes. That difference was not treated as justification for flashing.

VBIOS identifiers:

- Version: `017.003.000.008.017114`
- Part/board: `113-D3050301-X00`
- Board string: `NAVI12 A0 GLXLB D30503 8GB BC160 1150e/334m HYN/SAM`
- Build date: `2021-07-27 08:30`
- Subsystem: `1002:0A34`
