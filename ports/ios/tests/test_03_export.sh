#!/usr/bin/env bash
# AC-4, AC-6: real Godot export through build.sh.

# Runs `./build.sh ios-xcode` once per test subshell from a clean output directory.
export_xcode_project() {
	rm -rf "$XCODE_EXPORT"
	EXPORT_LOG=$("$ROOT/build.sh" ios-xcode 2>&1)
	EXPORT_RC=$?
}

test_xcode_project_export() {
	export_xcode_project
	assert_eq 0 "$EXPORT_RC" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$EXPORT_LOG")" || return 1
	local pbx="$XCODE_EXPORT/PHOBOS.xcodeproj/project.pbxproj"
	assert_file "$pbx" || return 1
	local content; content=$(cat "$pbx")
	assert_contains "$content" "PRODUCT_BUNDLE_IDENTIFIER = com.marek.piotrowski.phobos;" "pbxproj bundle id" || return 1
	assert_contains "$content" "DEVELOPMENT_TEAM = JMMW48F6X4;" "pbxproj team id" || return 1
	assert_contains "$content" 'TARGETED_DEVICE_FAMILY = "1,2";' "pbxproj device family iPhone+iPad" || return 1
	assert_not_contains "$content" "com.phobos.game" "macOS bundle id must not leak into iOS"
}

test_info_plist_landscape_and_encryption() {
	export_xcode_project
	assert_eq 0 "$EXPORT_RC" "build.sh ios-xcode exit code" || return 1
	local plist="$XCODE_EXPORT/PHOBOS/PHOBOS-Info.plist"
	assert_file "$plist" || return 1
	local landscape='["UIInterfaceOrientationLandscapeLeft","UIInterfaceOrientationLandscapeRight"]'
	assert_eq "$landscape" "$(plutil -extract UISupportedInterfaceOrientations json -o - "$plist")" "iPhone orientations" || return 1
	assert_eq "$landscape" "$(plutil -extract 'UISupportedInterfaceOrientations~ipad' json -o - "$plist")" "iPad orientations" || return 1
	assert_eq "false" "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$plist")" "export compliance: no non-exempt encryption"
}

test_pck_contents() {
	export_xcode_project
	assert_eq 0 "$EXPORT_RC" "build.sh ios-xcode exit code" || return 1
	assert_file "$XCODE_EXPORT/PrivacyInfo.xcprivacy" || return 1
	local pck="$XCODE_EXPORT/PHOBOS.pck"
	assert_file "$pck" || return 1
	local s; s=$(strings "$pck")
	assert_contains "$s" "assets/fonts/OFL-Oxanium.txt" "pck contains Oxanium licence" || return 1
	assert_contains "$s" "assets/fonts/OFL-Tektur.txt" "pck contains Tektur licence" || return 1
	assert_not_contains "$s" "concept_preview" "pck excludes concept preview"
}

test_signed_ipa() {
	[[ "${PHOBOS_IOS_SIGNED:-}" == 1 ]] || return $SKIP
	local ipa="$IOS_PROJECT/build/PHOBOS.ipa" log rc
	rm -f "$ipa"
	log=$("$ROOT/build.sh" ios 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh ios exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	assert_file "$ipa" || return 1
	assert_contains "$(unzip -l "$ipa")" "Payload/PHOBOS.app/" "ipa contains the app bundle"
}
