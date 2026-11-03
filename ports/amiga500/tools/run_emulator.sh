#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FS_UAE=${FS_UAE:-/Applications/FS-UAE.app/Contents/MacOS/fs-uae}
ADF="$ROOT/build/PHOBOS-A500.adf"
DEFAULT_KICKSTART="$HOME/Downloads/Kickstart v1.3 rev 34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV).rom"
KICKSTART_ROM=${KICKSTART_ROM:-$DEFAULT_KICKSTART}

[[ -x "$FS_UAE" ]] || {
	printf '%s\n' "Brak FS-UAE. Uruchom: brew bundle --file $ROOT/Brewfile"
	exit 1
}
[[ -f "$ADF" ]] || {
	printf '%s\n' "Brak ADF. Uruchom: make -C $ROOT all"
	exit 1
}

[[ -f "$KICKSTART_ROM" ]] || {
	printf '%s\n' "Nie znaleziono Kickstartu 1.3: $KICKSTART_ROM"
	exit 1
}

ARGS=("$FS_UAE" "$ROOT/config/a500.fs-uae" "--floppy_drive_0=$ADF" "--kickstart_file=$KICKSTART_ROM")

exec "${ARGS[@]}"
