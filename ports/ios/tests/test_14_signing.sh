#!/usr/bin/env bash
# Podpisywanie i izolacja testów:
# - konfiguracja Release projektu Xcode podpisuje się „Apple Development” (podpis automatyczny),
#   więc Run na telefonie działa od razu; dystrybucję do App Store podpisuje Organizer / eksport;
# - testy eksportują projekt do katalogu tymczasowego (PHOBOS_IOS_XCODE_DIR) i nie nadpisują
#   ports/ios/project/build/xcode, w którym użytkownik pracuje w Xcode.

# ------------------------------------------------------------ podpis

test_sign_presets_release_identity() {
	local p
	for p in "iOS" "iOS Xcode"; do
		assert_eq '"Apple Development"' "$(preset_value "$IOS_PRESETS" "$p" application/code_sign_identity_release)" "$p: Release signing identity" || return 1
	done
}

# characterization: distribution method stays App Store, signing stays automatic with the team
test_sign_presets_still_app_store() {
	local p
	for p in "iOS" "iOS Xcode"; do
		assert_eq '0' "$(preset_value "$IOS_PRESETS" "$p" application/export_method_release)" "$p: export method App Store" || return 1
		assert_eq '"JMMW48F6X4"' "$(preset_value "$IOS_PRESETS" "$p" application/app_store_team_id)" "$p: team id" || return 1
	done
}

test_sign_exported_project_has_no_distribution_identity() {
	rm -rf "$XCODE_EXPORT"
	local log rc
	log=$("$ROOT/build.sh" ios-xcode 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	local pbx="$XCODE_EXPORT/PHOBOS.xcodeproj/project.pbxproj"
	assert_file "$pbx" || return 1
	local content; content=$(cat "$pbx")
	assert_not_contains "$content" "Apple Distribution" "no configuration forces the distribution certificate (conflicts with automatic signing on Run)" || return 1
	assert_eq 4 "$(grep -c 'CODE_SIGN_IDENTITY = "Apple Development";' "$pbx")" "project + target, Debug + Release: Apple Development" || return 1
	# Godot writes the value quoted ("Automatic"); Xcode rewrites it unquoted after a save.
	assert_eq 2 "$(grep -cE 'CODE_SIGN_STYLE = "?Automatic"?;' "$pbx")" "automatic signing in Debug and Release" || return 1
	assert_eq 2 "$(grep -c 'DEVELOPMENT_TEAM = JMMW48F6X4;' "$pbx")" "team in Debug and Release"
}

# ------------------------------------------------------------ izolacja: katalog projektu użytkownika

test_tests_never_export_into_user_project() {
	case "$XCODE_EXPORT" in
		"$IOS_PROJECT"/*) fail "XCODE_EXPORT points into the iOS project: $XCODE_EXPORT" ;;
	esac || return 1
	assert_eq "$XCODE_EXPORT" "${PHOBOS_IOS_XCODE_DIR:-}" "lib.sh exports PHOBOS_IOS_XCODE_DIR = XCODE_EXPORT"
}

test_build_sh_honours_xcode_dir() {
	local tmp; tmp=$(mktemp -d)
	local sentinel="$USER_XCODE_DIR/.phobos-test-sentinel"
	mkdir -p "$USER_XCODE_DIR"
	echo keep >"$sentinel"
	local before=""
	[[ -f "$USER_XCODE_DIR/PHOBOS.xcodeproj/project.pbxproj" ]] && before=$(shasum "$USER_XCODE_DIR/PHOBOS.xcodeproj/project.pbxproj")
	local log rc
	log=$(PHOBOS_IOS_XCODE_DIR="$tmp/out" "$ROOT/build.sh" ios-xcode 2>&1); rc=$?
	local after=""
	[[ -f "$USER_XCODE_DIR/PHOBOS.xcodeproj/project.pbxproj" ]] && after=$(shasum "$USER_XCODE_DIR/PHOBOS.xcodeproj/project.pbxproj")
	local sentinel_left=no; [[ -f "$sentinel" ]] && sentinel_left=yes
	rm -f "$sentinel"
	assert_eq 0 "$rc" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$log")" || { rm -rf "$tmp"; return 1; }
	assert_file "$tmp/out/PHOBOS.xcodeproj/project.pbxproj" || { rm -rf "$tmp"; return 1; }
	assert_contains "$log" "$tmp/out/PHOBOS.xcodeproj" "build.sh prints where the project went" || { rm -rf "$tmp"; return 1; }
	rm -rf "$tmp"
	assert_eq yes "$sentinel_left" "user's build/xcode directory is left alone" || return 1
	assert_eq "$before" "$after" "user's PHOBOS.xcodeproj is not overwritten"
}

test_build_sh_help_documents_xcode_dir() {
	local out; out=$("$ROOT/build.sh" -h)
	assert_contains "$out" "PHOBOS_IOS_XCODE_DIR" "help documents the output directory override" || return 1
	assert_contains "$out" "ports/ios/project/build/xcode/PHOBOS.xcodeproj" "default output unchanged"
}
