#!/usr/bin/env bash
# Poprawki po audytach etapów 01 i 03: safe area tylko na iOS, teksty menu/inicjałów,
# jawna kategoria audio, ikona App Store bez przezroczystości.

ICON_RES="res://assets/ios/app_icon_1024.png"
ICON_FILE="$IOS_PROJECT/assets/ios/app_icon_1024.png"

# --- AC-1: safe area only on iOS (GDScript)
test_fix_effective_safe_area_ignored_off_ios() { run_gd test_fixes.gd test_effective_safe_area_ignored_off_ios; }
test_fix_effective_safe_area_used_on_ios()     { run_gd test_fixes.gd test_effective_safe_area_used_on_ios; }
test_fix_main_desktop_safe_area_is_empty()     { run_gd test_fixes.gd test_main_desktop_safe_area_is_empty; }
test_fix_mac_rect_does_not_shift_hud()         { run_gd test_fixes.gd test_mac_rect_does_not_shift_hud; }

# --- AC-2: menu and initials screens (GDScript)
test_fix_menu_and_initials_fit_169()           { run_gd test_fixes.gd test_menu_and_initials_fit_169; }
test_fix_menu_and_initials_fit_iphone()        { run_gd test_fixes.gd test_menu_and_initials_fit_iphone; }
test_fix_menu_and_initials_fit_ipad()          { run_gd test_fixes.gd test_menu_and_initials_fit_ipad; }

# --- AC-3: audio session stated explicitly
test_fix_audio_session_explicit() {
	local section
	section=$(awk '/^\[/{s=$0} /^general\/ios\/session_category=0$/{print s}' "$IOS_PROJECT/project.godot")
	assert_eq "[audio]" "$section" "project.godot sets general/ios/session_category=0 (Ambient) in [audio]"
}

# --- AC-4: App Store icon without alpha
test_fix_icon_source_opaque() {
	assert_file "$ICON_FILE" || return 1
	assert_eq "1024" "$(sips -g pixelWidth "$ICON_FILE" | awk '/pixelWidth/{print $2}')" "icon width" || return 1
	assert_eq "1024" "$(sips -g pixelHeight "$ICON_FILE" | awk '/pixelHeight/{print $2}')" "icon height" || return 1
	assert_eq "no" "$(sips -g hasAlpha "$ICON_FILE" | awk '/hasAlpha/{print $2}')" "icon source has no alpha channel"
}

test_fix_icon_presets() {
	local p
	for p in "iOS" "iOS Xcode"; do
		assert_eq "\"$ICON_RES\"" "$(preset_value "$IOS_PRESETS" "$p" icons/app_store_1024x1024)" "$p: App Store icon" || return 1
		assert_eq "\"$ICON_RES\"" "$(preset_value "$IOS_PRESETS" "$p" icons/icon_1024x1024)" "$p: base icon for generated sizes" || return 1
	done
}

test_fix_exported_icons_opaque() {
	rm -rf "$XCODE_EXPORT"
	local log rc
	log=$("$ROOT/build.sh" ios-xcode 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	local dir="$XCODE_EXPORT/PHOBOS/Images.xcassets/AppIcon.appiconset" f with_alpha=()
	assert_file "$dir/Icon-1024.png" || return 1
	for f in "$dir"/*.png; do
		[[ "$(sips -g hasAlpha "$f" | awk '/hasAlpha/{print $2}')" == "no" ]] || with_alpha+=("$(basename "$f")")
	done
	assert_eq "" "${with_alpha[*]-}" "exported app icons with an alpha channel (App Store rejects them)"
}
