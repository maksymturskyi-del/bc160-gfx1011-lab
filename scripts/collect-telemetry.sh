#!/usr/bin/env bash
set -euo pipefail
INTERVAL="${1:-5}"

find_hwmon() {
  for h in /sys/class/drm/card*/device/hwmon/hwmon*; do
    [[ -r "$h/name" ]] && grep -qi '^amdgpu$' "$h/name" && { echo "$h"; return; }
  done
}
H="${HWMON:-$(find_hwmon)}"

echo "timestamp,edge_c,hotspot_c,memory_c,pwm,rpm,power_w"
while true; do
  read_t() { local f="$1"; [[ -r "$f" ]] && awk '{printf "%.1f",$1/1000}' "$f" || printf ''; }
  edge=$(read_t "$H/temp1_input")
  hot=$(read_t "$H/temp2_input")
  mem=$(read_t "$H/temp3_input")
  pwm=$([[ -r "$H/pwm1" ]] && cat "$H/pwm1" || true)
  rpm=$([[ -r "$H/fan1_input" ]] && cat "$H/fan1_input" || true)
  if [[ -r "$H/power1_average" ]]; then
    power=$(awk '{printf "%.1f",$1/1000000}' "$H/power1_average")
  else
    power=""
  fi
  echo "$(date -Is),$edge,$hot,$mem,$pwm,$rpm,$power"
  sleep "$INTERVAL"
done
