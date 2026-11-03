#!/usr/bin/env bash
# AC-1, AC-2: ports/ios/project is a faithful copy of project/ at the BASELINE commit.

# Files allowed to differ from the macOS original.
ALLOWED_DIFF=(project.godot export_presets.cfg)

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
	local expected actual
	expected=$(git -C "$ROOT" ls-tree -r --name-only "$base" -- project/ | sed 's#^project/##' | sort)
	actual=$(git -C "$ROOT" ls-files -co --exclude-standard -- ports/ios/project/ | sed 's#^ports/ios/project/##' | sort)
	assert_eq "$expected" "$actual" "file set of ports/ios/project equals project/ at BASELINE"
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
	assert_eq "" "${bad[*]-}" "files differing from BASELINE (only project.godot/export_presets.cfg may differ)"
}

test_project_godot_only_orientation_added() {
	local base; base=$(baseline_commit)
	[[ -n "$base" ]] || fail "BASELINE missing" || return 1
	assert_file "$IOS_PROJECT/project.godot" || return 1
	local diff
	diff=$(diff <(git -C "$ROOT" show "$base:project/project.godot") "$IOS_PROJECT/project.godot" | grep -E '^[<>]')
	assert_eq "> window/handheld/orientation=4" "$diff" "project.godot differs only by the added orientation line" || return 1
	# the line must sit inside [display]
	local section
	section=$(awk '/^\[/{s=$0} /^window\/handheld\/orientation=/{print s}' "$IOS_PROJECT/project.godot")
	assert_eq "[display]" "$section" "orientation line is in [display]"
}
