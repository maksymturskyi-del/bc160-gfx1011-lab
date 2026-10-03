#!/usr/bin/env bash
# Reconstructed fan-curve controller from the verified working behavior.
# Review hwmon discovery on your machine before production use.
set -euo pipefail

POLL=5
HYST=2
SPINUP_PWM=110
SPINUP_SECONDS=2

find_hwmon() {
  for h in /sys/class/drm/card*/device/hwmon/hwmon*; do
    [[ -r "$h/name" ]] || continue
    if grep -qi '^amdgpu$' "$h/name"; then
      local dev
      dev="$(readlink -f "$h/../.." 2>/dev/null || true)"
      if [[ "$dev" == *"0000:03:00.0"* ]] || [[ -r "$h/pwm1" ]]; then
        printf '%s\n' "$h"
        return 0
      fi
    fi
  done
  return 1
}

HWMON="${HWMON:-$(find_hwmon)}"
PWM_ENABLE="$HWMON/pwm1_enable"
PWM="$HWMON/pwm1"
RPM="$HWMON/fan1_input"

restore_auto() {
  [[ -w "$PWM_ENABLE" ]] && echo 2 > "$PWM_ENABLE" || true
}
trap restore_auto EXIT INT TERM

for f in "$PWM_ENABLE" "$PWM" "$RPM" "$HWMON/temp1_input"; do
  [[ -e "$f" ]] || { echo "missing sysfs node: $f" >&2; exit 1; }
done

target_for_temp() {
  local t=$1
  if   (( t < 75 )); then echo 79
  elif (( t < 80 )); then echo 95
  elif (( t < 85 )); then echo 110
  elif (( t <= 90 )); then echo 126
  else echo 160
  fi
}

read_max_temp_c() {
  local max=-1000 v f
  for f in "$HWMON"/temp{1,2,3}_input; do
    [[ -r "$f" ]] || continue
    v=$(<"$f")
    (( v /= 1000 ))
    (( v > max )) && max=$v
  done
  (( max > -1000 )) || return 1
  echo "$max"
}

echo 1 > "$PWM_ENABLE"
current=""
current_band_temp=""

while true; do
  temp="$(read_max_temp_c)" || { echo "temperature read failed" >&2; exit 1; }
  desired="$(target_for_temp "$temp")"

  # Simple hysteresis: only step down when at least HYST below the lower boundary.
  if [[ -n "$current" && "$desired" -lt "$current" ]]; then
    case "$current" in
      95)  (( temp >= 75-HYST )) && desired=95 ;;
      110) (( temp >= 80-HYST )) && desired=110 ;;
      126) (( temp >= 85-HYST )) && desired=126 ;;
      160) (( temp >  90-HYST )) && desired=160 ;;
    esac
  fi

  if [[ "$desired" != "$current" ]]; then
    old="${current:-unknown}"
    if [[ "$(<"$RPM")" -eq 0 && "$desired" -ge 79 ]]; then
      echo "$SPINUP_PWM" > "$PWM"
      sleep "$SPINUP_SECONDS"
    fi
    echo "$desired" > "$PWM"
    sleep 1
    echo "$(date -Is) temp=${temp}C pwm ${old}->${desired} rpm=$(<"$RPM")"
    current="$desired"
  fi
  sleep "$POLL"
done
