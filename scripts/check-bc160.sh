#!/usr/bin/env bash
set -u
DEV="0000:03:00.0"
SYS="/sys/bus/pci/devices/$DEV"

echo "== lspci =="
lspci -s 03:00.0 -nnk || true

echo "== PCIe link =="
lspci -s 03:00.0 -vv 2>/dev/null | grep -E 'LnkCap:|LnkSta:' || true

echo "== Runtime PM =="
for f in power/control power/runtime_status d3cold_allowed; do
  if [[ -r "$SYS/$f" ]]; then printf '%-24s %s\n' "$f" "$(<"$SYS/$f")"; fi
done

echo "== Services =="
systemctl --no-pager --full status bc160-fan-curve.service 2>/dev/null | sed -n '1,8p' || true

echo "== Recent GPU/PCIe errors =="
journalctl -k -n 500 --no-pager | grep -Ei 'amdgpu|aer|pcie|vm fault|ring.*timeout|sdma.*timeout|gpu reset|d3cold' | tail -n 80 || true
