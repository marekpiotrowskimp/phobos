#!/usr/bin/env bash
# Uruchamia `PHOBOS --demo` w FS-UAE (A500 PAL, Kickstart 1.3), zbiera log i zrzuty
# z portu szeregowego, a następnie zamienia zrzuty ekranu na PNG.
# Wynik: build/demo/serial.log, build/demo/*.png
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/toolchain.lock"
FS_UAE=${FS_UAE:-/Applications/FS-UAE.app/Contents/MacOS/fs-uae}
DEFAULT_KICKSTART="$HOME/Downloads/Kickstart v1.3 rev 34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV).rom"
KICKSTART_ROM=${KICKSTART_ROM:-$DEFAULT_KICKSTART}
TIMEOUT=${DEMO_TIMEOUT:-600}
OUT="$ROOT/build/demo"
ADF="$OUT/PHOBOS-DEMO.adf"

[[ -x "$FS_UAE" ]] || { printf '%s\n' "Brak FS-UAE: $FS_UAE"; exit 1; }
[[ -f "$KICKSTART_ROM" ]] || { printf '%s\n' "Brak Kickstartu 1.3: $KICKSTART_ROM"; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
printf 'PHOBOS --demo\n' >"$OUT/startup-sequence"
uv tool run --from "amitools==$AMITOOLS_VERSION" xdftool "$ADF" format DEMO ofs + boot install boot1x \
	+ makedir S + write "$OUT/startup-sequence" S/startup-sequence + write "$ROOT/build/PHOBOS" PHOBOS >/dev/null
: >"$OUT/serial.log"

"$FS_UAE" "$ROOT/config/a500.fs-uae" --floppy_drive_0="$ADF" --kickstart_file="$KICKSTART_ROM" \
	--serial_port="$OUT/serial.log" --warp_mode="${DEMO_WARP:-1}" --writable_floppy_images=1 >"$OUT/fs-uae.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for ((second = 0; second < TIMEOUT; ++second)); do
	if grep -aq '@@DONE' "$OUT/serial.log"; then
		break
	fi
	if ! kill -0 $PID 2>/dev/null; then
		break
	fi
	sleep 1
done
sleep 1
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true
trap - EXIT

uv run --with pillow==11.3.0 python "$ROOT/tools/render_dump.py" "$OUT/serial.log" "$OUT"
grep -aq '@@DONE' "$OUT/serial.log" || { printf '%s\n' "Demo nie zakończyło się w ${TIMEOUT}s"; exit 1; }
