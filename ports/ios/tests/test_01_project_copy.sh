#!/usr/bin/env bash
# AC-1, AC-2 (etap 01) + zmiany dozwolone w etapach 02–03:
# ports/ios/project is a copy of project/ at the BASELINE commit; only the files listed
# below may differ and only new files under scripts/touch/ and scripts/ui/ may be added.

# Files allowed to differ from the macOS original.
ALLOWED_DIFF=(project.godot export_presets.cfg scripts/main.gd scripts/hud.gd)
# New iOS-only files (paths relative to the iOS project) must match this pattern.
NEW_FILES_PATTERN='^scripts/(touch|ui)/[a-z_]+\.gd(\.uid)?$'

test_baseline_is_existing_commit() {
	assert_file "$IOS_DIR/BASELINE" || return 1
	assert_eq 1 "$(wc -l < "$IOS_DIR/BASELINE" | tr -d ' ')" "BASELINE has exactly one line" || return 1
	local hash; hash=$(baseline_commit)
	[[ "$hash" =~ ^[0-9a-f]{40}$ ]] || fail "BASELINE is not a 40-char hash: $hash" || return 1
	git -C "$ROOT" cat-file -e "$hash^{commit}" 2>/dev/null || fail "BASELINE commit does not exist: $hash"
}

test_copy_has_same_file_set() {
	assert_dir "$IOS_PROJECT" || return 1
	local base; base=$(baseline_commit)
	[[ -n "$base" ]] || fail "BASELINE missing" || return 1
	local expected actual missing extra
	expected=$(git -C "$ROOT" ls-tree -r --name-only "$base" -- project/ | sed 's#^project/##' | sort)
	actual=$(git -C "$ROOT" ls-files -co --exclude-standard -- ports/ios/project/ | sed 's#^ports/ios/project/##' | sort)
	missing=$(comm -23 <(echo "$expected") <(echo "$actual"))
	extra=$(comm -13 <(echo "$expected") <(echo "$actual") | grep -Ev "$NEW_FILES_PATTERN")
	assert_eq "" "$missing" "files of project/ at BASELINE missing from the iOS copy" || return 1
	assert_eq "" "$extra" "unexpected new files (only scripts/touch/*.gd and scripts/ui/*.gd allowed)"
}

test_copy_files_identical() {
	local base; base=$(baseline_commit)
	[[ -n "$base" ]] || fail "BASELINE missing" || return 1
	assert_dir "$IOS_PROJECT" || return 1
	local f rel bad=()
	while IFS= read -r f; do
		rel=${f#project/}
		[[ " ${ALLOWED_DIFF[*]} " == *" $rel "* ]] && continue
		if ! cmp -s <(git -C "$ROOT" show "$base:$f") "$IOS_PROJECT/$rel"; then
			bad+=("$rel")
		fi
	done < <(git -C "$ROOT" ls-tree -r --name-only "$base" -- project/)
	assert_eq "" "${bad[*]-}" "files differing from BASELINE (only ${ALLOWED_DIFF[*]} may differ)"
}

test_project_godot_only_ios_settings() {
	local base; base=$(baseline_commit)
	[[ -n "$base" ]] || fail "BASELINE missing" || return 1
	assert_file "$IOS_PROJECT/project.godot" || return 1
	local removed added
	removed=$(diff <(git -C "$ROOT" show "$base:project/project.godot") "$IOS_PROJECT/project.godot" | grep -E '^<')
	added=$(diff <(git -C "$ROOT" show "$base:project/project.godot") "$IOS_PROJECT/project.godot" | grep -E '^>' | grep -Ev '^> *$' | sort)
	# the only original line that may change: stretch aspect keep → expand (etap 03)
	assert_eq '< window/stretch/aspect="keep"' "$removed" "project.godot: only the stretch aspect line of the original may change" || return 1
	assert_eq $'> [input_devices]\n> pointing/emulate_mouse_from_touch=false\n> window/handheld/orientation=4\n> window/stretch/aspect="expand"' "$added" "project.godot: only the iOS settings are added" || return 1
	local section
	section=$(awk '/^\[/{s=$0} /^window\/handheld\/orientation=/{print s}' "$IOS_PROJECT/project.godot")
	assert_eq "[display]" "$section" "orientation line is in [display]" || return 1
	section=$(awk '/^\[/{s=$0} /^pointing\/emulate_mouse_from_touch=/{print s}' "$IOS_PROJECT/project.godot")
	assert_eq "[input_devices]" "$section" "mouse emulation line is in [input_devices]"
}
