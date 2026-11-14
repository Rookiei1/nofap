#!/bin/bash
# Home screenshots for a regular iPhone, a small iPhone, and an accessibility text size.
# The debug launch argument shows 12 days and 08:42:16 without touching a saved streak.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/screenshots"
mkdir -p "$OUT"
cp "$ROOT/NoFap/Assets.xcassets/AppIcon.appiconset/AppIcon.png" "$OUT/AppIcon.png"
sips -z 180 180 "$OUT/AppIcon.png" --out "$OUT/AppIcon-180.png" >/dev/null

APP="$(find "$ROOT/build/DerivedData" -path '*Debug-iphonesimulator/NoFap.app' -type d | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "Debug app was not built." >&2
  exit 1
fi

python3 - <<'PY' > "$OUT/devices.txt"
import json, subprocess
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
phones = []
for runtime, devices in data["devices"].items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            phones.append(device)

def pick(predicate):
    for device in phones:
        if predicate(device["name"]):
            return device
    return None

regular = (
    pick(lambda name: name in {"iPhone 16", "iPhone 17"})
    or pick(lambda name: "Pro" in name and "Max" not in name)
    or (phones[0] if phones else None)
)
small = pick(lambda name: "SE" in name or "mini" in name) or regular
if regular is None:
    raise SystemExit("No iPhone simulator is available")
print(regular["udid"])
print(regular["name"].replace(" ", "-"))
print(small["udid"])
print(small["name"].replace(" ", "-"))
PY
mapfile -t PICKED < "$OUT/devices.txt"

shoot() {
  local udid="$1"
  local name="$2"
  local size="$3"
  xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$APP"
  if [[ -n "$size" ]]; then
    xcrun simctl ui "$udid" content_size "$size" || echo "content_size $size is unavailable on this simulator"
  else
    xcrun simctl ui "$udid" content_size large || true
  fi
  xcrun simctl terminate "$udid" com.rookiei1.nofap || true
  xcrun simctl launch "$udid" com.rookiei1.nofap -NoFapOffsetSeconds 1068136
  sleep 4
  xcrun simctl io "$udid" screenshot "$OUT/home-${name}.png"
}

shoot "${PICKED[0]}" "${PICKED[1]}" ""
shoot "${PICKED[0]}" "${PICKED[1]}-accessibility" "accessibility-extra-extra-extra-large"
if [[ "${PICKED[2]}" != "${PICKED[0]}" ]]; then
  shoot "${PICKED[2]}" "${PICKED[3]}" ""
fi

find "$OUT" -name '*.png' -print
