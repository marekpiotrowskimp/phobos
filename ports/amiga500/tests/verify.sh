#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/toolchain.lock"

PROGRAM="$ROOT/build/PHOBOS"
ADF="$ROOT/build/PHOBOS-A500.adf"
AMITOOLS=(uv tool run --from "amitools==$AMITOOLS_VERSION" --with "machine68k==0.3.0")
VAMOS=(uv tool run --from "amitools==$AMITOOLS_VERSION" --with "machine68k==0.3.0")

[[ -x "$PROGRAM" ]]
[[ -f "$ADF" ]]
[[ $(stat -f %z "$ADF") -eq 901120 ]]

HUNK_INFO=$("${AMITOOLS[@]}" hunktool info "$PROGRAM" 2>&1 || true)
grep -q TYPE_LOADSEG <<<"$HUNK_INFO"
"${AMITOOLS[@]}" xdftool "$ADF" list >/dev/null
"${AMITOOLS[@]}" xdftool "$ADF" type S/startup-sequence | grep -qx PHOBOS
"${AMITOOLS[@]}" xdftool "$ADF" list | grep -q PHOBOS
"${VAMOS[@]}" vamos -C 68000 -m 1024 -O graphics.library=mode:fake -O intuition.library=mode:fake -- "$PROGRAM" --self-test | grep -q "PHOBOS A500 STAGE5 OK"

CURRENT_PROJECT_TREE=$(git -C "$ROOT/../.." rev-parse HEAD:project)
[[ "$CURRENT_PROJECT_TREE" == "$PROJECT_TREE_BASELINE" ]]

printf '%s\n' "Amiga verification passed"
