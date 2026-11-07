#!/usr/bin/env bash
# AC-5, AC-7: build.sh iOS targets.

test_help_lists_ios_targets() {
	local out
	out=$("$ROOT/build.sh" -h) || fail "build.sh -h exited non-zero" || return 1
	grep -qE '^  ios +' <<<"$out" || fail "help has no 'ios' target line" || return 1
	grep -qE '^  ios-xcode +' <<<"$out" || fail "help has no 'ios-xcode' target line" || return 1
	local all_line; all_line=$(grep -E '^  all ' <<<"$out")
	assert_not_contains "$(tr '[:upper:]' '[:lower:]' <<<"$all_line")" "ios" "'all' must not build iOS"
}

test_ios_requires_full_xcode() {
	local clt=/Library/Developer/CommandLineTools target out err rc
	[[ -d "$clt" ]] || return $SKIP
	for target in ios ios-xcode; do
		err=$(DEVELOPER_DIR="$clt" "$ROOT/build.sh" "$target" 2>&1 >/dev/null); rc=$?
		out=$(DEVELOPER_DIR="$clt" "$ROOT/build.sh" "$target" 2>/dev/null)
		assert_eq 1 "$rc" "$target without full Xcode: exit code" || return 1
		assert_contains "$err" "Xcode" "$target without full Xcode: stderr mentions Xcode" || return 1
		assert_not_contains "$(tr '[:upper:]' '[:lower:]' <<<"$out$err")" "export" "$target: export must not start" || return 1
	done
}
