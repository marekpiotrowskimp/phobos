#!/usr/bin/env bash
# AC-8: ports/ios/tools/diff_from_macos.sh lists macOS changes since the iOS copy.

TOOL="$IOS_DIR/tools/diff_from_macos.sh"

test_no_changes_since_baseline() {
	[[ -x "$TOOL" ]] || fail "missing or not executable: ports/ios/tools/diff_from_macos.sh" || return 1
	local out rc
	out=$("$TOOL"); rc=$?
	assert_eq 0 "$rc" "exit code" || return 1
	assert_eq "" "$out" "no output when project/ is unchanged since BASELINE"
}

test_explicit_base_lists_changes() {
	[[ -x "$TOOL" ]] || fail "missing or not executable: ports/ios/tools/diff_from_macos.sh" || return 1
	local out rc
	out=$("$TOOL" --base f1dfc4f); rc=$?
	assert_eq 0 "$rc" "exit code" || return 1
	assert_eq $'M\tproject/README.md' "$out" "changes in project/ since f1dfc4f"
}

test_invalid_base_fails() {
	[[ -x "$TOOL" ]] || fail "missing or not executable: ports/ios/tools/diff_from_macos.sh" || return 1
	local out err rc
	err=$("$TOOL" --base deadbeef 2>&1 >/dev/null); rc=$?
	out=$("$TOOL" --base deadbeef 2>/dev/null)
	assert_eq 2 "$rc" "exit code for unknown commit" || return 1
	assert_eq "" "$out" "nothing on stdout" || return 1
	[[ -n "$err" ]] || fail "error message on stderr"
}
