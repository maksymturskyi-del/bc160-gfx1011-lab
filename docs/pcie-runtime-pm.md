# PCIe and runtime power management

## Failure mode

The card could fully initialize, remain usable for roughly 50 seconds, and then lose the link / enter a broken runtime power transition. The important observation was that amdgpu/BOCO changed PCI runtime policy back to `auto` roughly 10–11 seconds after initialization.

The failure was therefore not basic PCIe enumeration and not primarily a signal-integrity problem.

## Working policy

The stable runtime state used during all later compute/inference tests was:

```text
power/control = on
runtime_status = active
```

When exported by the kernel, `d3cold_allowed` was forced to `0`.

A systemd workaround reasserted `power/control=on` after amdgpu changed it back to `auto`.

## Kernel boot parameters used during diagnosis

At one stage the diagnostic boot used:

```text
pcie_aspm=off amdgpu.runpm=0
```

The long-term result was driven primarily by explicit sysfs/runtime-PM policy; this repository does not claim those two kernel parameters are universally required.

## Validation criteria

After every meaningful test the following were checked:

- BC-160 still present in `lspci`
- amdgpu still bound
- endpoint side link remains `16 GT/s x16`
- `power/control=on`
- `runtime_status=active`
- PM workaround service active
- no new AER errors
- no VM fault
- no ring/SDMA timeout
- no GPU reset
- no PCIe link drop
