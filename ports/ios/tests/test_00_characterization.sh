#!/usr/bin/env bash
# Characterization: behaviour that existed before the iOS port and must not change.

test_help_lists_existing_targets() {
	local out
	out=$("$ROOT/build.sh" -h) || fail "build.sh -h exited non-zero" || return 1
	assert_contains "$out" "  all     (default) build both platforms" "help: all target" || return 1
	assert_contains "$out" "  macos   Godot export   → project/build/PHOBOS.app" "help: macos target" || return 1
	assert_contains "$out" "  amiga   Amiga 500 port → ports/amiga500/build/PHOBOS-A500.adf" "help: amiga target" || return 1
	assert_contains "$out" "  clean   remove build outputs of both platforms" "help: clean target"
}

test_unknown_target_fails() {
	local out rc
	out=$("$ROOT/build.sh" bogus 2>&1); rc=$?
	assert_eq 1 "$rc" "unknown target exit code" || return 1
	assert_contains "$out" "Unknown target: bogus" "unknown target message"
}

test_macos_preset_unchanged() {
	assert_eq "macOS" "$(preset_names "$MACOS_PRESETS")" "project/ has exactly one preset, macOS" || return 1
	assert_eq '"macOS"' "$(preset_value "$MACOS_PRESETS" macOS platform)" "macOS preset platform" || return 1
	assert_eq '"com.phobos.game"' "$(preset_value "$MACOS_PRESETS" macOS application/bundle_identifier)" "macOS bundle id unchanged"
}

test_project_tree_untouched() {
	assert_eq "" "$(git -C "$ROOT" status --porcelain -- project/)" "project/ has no uncommitted or untracked changes"
}

test_amiga_tree_untouched() {
	assert_eq "" "$(git -C "$ROOT" status --porcelain -- ports/amiga500/)" "ports/amiga500/ has no uncommitted or untracked changes"
}

test_macos_build_still_works() {
	local log rc
	log=$("$ROOT/build.sh" macos 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh macos exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	[[ -x "$ROOT/project/build/PHOBOS.app/Contents/MacOS/PHOBOS" ]] || fail "PHOBOS.app executable missing"
}
