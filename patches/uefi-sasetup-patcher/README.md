# One-shot SaSetup UEFI patcher

The original custom EDK II source is not reproduced here because this repository was reconstructed from the verified run notes rather than copied from the diagnostic machine.

Verified behavior of the working patcher:

- X64 EDK II UEFI application
- temporarily installed as `EFI/BOOT/BOOTX64.EFI`
- canonical systemd-boot binary retained separately
- one-shot marker created before modification
- finds `SaSetup` GUID `72C5E28C-7783-43A1-8767-FAD73FCCAFA4`
- requires variable size `0x427`
- verifies old bytes:
  - `0x0BA == 0x03`
  - `0x0C0 == 0x02`
- writes:
  - `0x0BA = 0x00` (IGFX)
  - `0x0C0 = 0x01` (Internal Graphics Enabled)
- re-reads full variable and verifies that exactly those two payload bytes changed
- chainloads canonical systemd-boot

Known patcher SHA256:

`9ac91fc5a2ac4981ac1dd52643ad945f5e6fbe333e0bdbba39373e4998db14ca`

Do not implement a blind writer. Any recreation should keep all of the precondition checks and one-shot behavior above.
