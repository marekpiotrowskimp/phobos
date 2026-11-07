#!/usr/bin/env bash
# Runs every test_* function from ports/ios/tests/test_*.sh, each in its own subshell.
# Exit code: 0 when nothing failed (skips allowed), 1 otherwise.
# Usage: run_tests.sh [file-glob-filter] [function-filter]
set -uo pipefail

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FILE_FILTER=${1:-}
FUNC_FILTER=${2:-}
pass=0 failed=0 skipped=0
failures=()

for file in "$TESTS_DIR"/test_*.sh; do
	[[ -z "$FILE_FILTER" || "$(basename "$file")" == *"$FILE_FILTER"* ]] || continue
	funcs=$(grep -oE '^test_[a-zA-Z0-9_]+\(\)' "$file" | tr -d '()')
	for fn in $funcs; do
		[[ -z "$FUNC_FILTER" || "$fn" == *"$FUNC_FILTER"* ]] || continue
		(
			set -uo pipefail
			# shellcheck source=lib.sh
			source "$TESTS_DIR/lib.sh"
			# shellcheck disable=SC1090
			source "$file"
			cd "$ROOT" || exit 1
			"$fn"
		)
		rc=$?
		name="$(basename "$file"): $fn"
		case $rc in
			0) printf 'PASS  %s\n' "$name"; pass=$((pass + 1)) ;;
			77) printf 'SKIP  %s\n' "$name"; skipped=$((skipped + 1)) ;;
			*) printf 'FAIL  %s\n' "$name"; failed=$((failed + 1)); failures+=("$name") ;;
		esac
	done
done

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$failed" "$skipped"
for f in "${failures[@]+"${failures[@]}"}"; do printf '  FAILED: %s\n' "$f"; done
[[ $failed -eq 0 ]]
