#!/usr/bin/env bash
# AC-3: export presets of the iOS project.

test_exactly_two_ios_presets() {
	assert_file "$IOS_PRESETS" || return 1
	assert_eq $'iOS\niOS Xcode' "$(preset_names "$IOS_PRESETS")" "preset names (in order)" || return 1
	assert_eq '"iOS"' "$(preset_value "$IOS_PRESETS" "iOS" platform)" "platform of preset iOS" || return 1
	assert_eq '"iOS"' "$(preset_value "$IOS_PRESETS" "iOS Xcode" platform)" "platform of preset iOS Xcode"
}

test_common_options() {
	assert_file "$IOS_PRESETS" || return 1
	local exclude p
	exclude=$(preset_value "$MACOS_PRESETS" macOS exclude_filter)
	for p in "iOS" "iOS Xcode"; do
		assert_eq '"com.marek.piotrowski.phobos"' "$(preset_value "$IOS_PRESETS" "$p" application/bundle_identifier)" "$p: bundle id" || return 1
		assert_eq '"JMMW48F6X4"' "$(preset_value "$IOS_PRESETS" "$p" application/app_store_team_id)" "$p: team id" || return 1
		assert_eq '2' "$(preset_value "$IOS_PRESETS" "$p" application/targeted_device_family)" "$p: iPhone + iPad" || return 1
		assert_eq '"assets/fonts/*.txt"' "$(preset_value "$IOS_PRESETS" "$p" include_filter)" "$p: include_filter" || return 1
		assert_eq "$exclude" "$(preset_value "$IOS_PRESETS" "$p" exclude_filter)" "$p: exclude_filter same as macOS" || return 1
	done
}

test_preset_specific_options() {
	assert_file "$IOS_PRESETS" || return 1
	assert_eq 'false' "$(preset_value "$IOS_PRESETS" "iOS" application/export_project_only)" "iOS: builds archive + ipa" || return 1
	assert_eq '"build/PHOBOS.ipa"' "$(preset_value "$IOS_PRESETS" "iOS" export_path)" "iOS: export path" || return 1
	assert_eq '0' "$(preset_value "$IOS_PRESETS" "iOS" application/export_method_release)" "iOS: release method App Store" || return 1
	assert_eq 'true' "$(preset_value "$IOS_PRESETS" "iOS Xcode" application/export_project_only)" "iOS Xcode: project only" || return 1
	assert_eq '"build/xcode/PHOBOS.xcodeproj"' "$(preset_value "$IOS_PRESETS" "iOS Xcode" export_path)" "iOS Xcode: export path"
}
