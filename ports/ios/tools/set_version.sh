#!/usr/bin/env bash
# Sets the App Store version and build number in both iOS export presets.
#
#   ports/ios/tools/set_version.sh <wersja> <build> [--presets <export_presets.cfg>]
#
#   <wersja>  CFBundleShortVersionString, X.Y.Z — must equal the macOS version
#             (project/export_presets.cfg), the iOS port follows the macOS release
#   <build>   CFBundleVersion, a positive integer higher than the current one
#             (App Store Connect rejects an upload whose build number was already used)
#
# Only application/short_version and application/version change; a rejected call changes nothing.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
PRESETS="$ROOT/ports/ios/project/export_presets.cfg"
MACOS_PRESETS="$ROOT/project/export_presets.cfg"

usage() {
	echo "usage: ports/ios/tools/set_version.sh <wersja X.Y.Z> <build> [--presets <export_presets.cfg>]" >&2
	exit 1
}
die() { echo "set_version.sh: $*" >&2; exit 1; }

args=()
while (( $# )); do
	case $1 in
		--presets) (( $# >= 2 )) || usage; PRESETS=$2; shift 2 ;;
		-h|--help) usage ;;
		*) args+=("$1"); shift ;;
	esac
done
(( ${#args[@]} == 2 )) || usage
version=${args[0]}
build=${args[1]}

[[ -f "$PRESETS" ]] || die "no presets file: $PRESETS"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must be X.Y.Z, got '$version'"
[[ "$build" =~ ^[1-9][0-9]*$ ]] || die "build must be a positive integer, got '$build'"

macos_version=$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' "$MACOS_PRESETS" | head -1)
[[ -n "$macos_version" ]] || die "cannot read the macOS version from $MACOS_PRESETS"
[[ "$version" == "$macos_version" ]] || die "version $version differs from the macOS version $macos_version"

python3 -I - "$PRESETS" "$version" "$build" <<'PY'
import re, sys
path, version, build = sys.argv[1], sys.argv[2], int(sys.argv[3])
text = open(path, encoding="utf-8").read()
current = re.findall(r'^application/version="(.*)"$', text, re.M)
if len(current) != 2:
    sys.exit(f"set_version.sh: expected application/version in 2 presets, found {len(current)}")
numeric = [int(v) for v in current if re.fullmatch(r"[0-9]+", v)]
highest = max(numeric) if numeric else 0
if build <= highest:
    sys.exit(f"set_version.sh: build {build} must be higher than the current build {highest}")
text, n_short = re.subn(r'^application/short_version=".*"$', f'application/short_version="{version}"', text, flags=re.M)
text, n_build = re.subn(r'^application/version=".*"$', f'application/version="{build}"', text, flags=re.M)
if n_short != 2 or n_build != 2:
    sys.exit("set_version.sh: presets layout unexpected, nothing changed")
open(path, "w", encoding="utf-8").write(text)
print(f"iOS: {version} ({build})")
PY
