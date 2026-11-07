#!/usr/bin/env bash
# Lists changes in the macOS project (project/) since the commit the iOS copy was made from,
# so they can be carried over to ports/ios/project/ deliberately.
#
# Usage: diff_from_macos.sh [--base <commit>]
#   Default base: the commit in ports/ios/BASELINE.
#   Output: `git diff --name-status` lines (working tree included) and `??<TAB>path`
#   for untracked files. No output means no changes. Exit 2 on a bad argument or commit.
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
BASELINE_FILE="$ROOT/ports/ios/BASELINE"

die() { printf '%s\n' "$*" >&2; exit 2; }

base=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--base)
			[[ $# -ge 2 && -n "$2" ]] || die "--base requires a commit"
			base=$2
			shift 2
			;;
		-h|--help)
			sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*) die "Unknown argument: $1" ;;
	esac
done

if [[ -z "$base" ]]; then
	[[ -f "$BASELINE_FILE" ]] || die "Missing $BASELINE_FILE"
	base=$(tr -d '[:space:]' < "$BASELINE_FILE")
fi

git -C "$ROOT" rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "Unknown commit: $base"

git -C "$ROOT" diff --name-status "$base" -- project/
git -C "$ROOT" ls-files --others --exclude-standard -- project/ | awk '{ print "??\t" $0 }'
