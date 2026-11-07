#!/usr/bin/env bash
# Etap 04 — App Store i zgodność: ekran LICENCJE, klucze Info.plist, privacy manifest
# oraz materiały do App Store Connect w ports/ios/release/ (agent przygotowuje, użytkownik wkleja).

RELEASE="$IOS_DIR/release"
APP_NAME="PHOBOS Survivor"

# ------------------------------------------------------------ ekran LICENCJE (gd)
test_store_credits_game_licence()        { run_gd test_credits.gd test_credits_game_licence; }
test_store_credits_font_licences()       { run_gd test_credits.gd test_credits_contains_full_font_licences; }
test_store_credits_godot_licence()       { run_gd test_credits.gd test_credits_contains_godot_licence; }
test_store_credits_third_party()         { run_gd test_credits.gd test_credits_contains_third_party_notices; }
test_store_credits_ai_note()             { run_gd test_credits.gd test_credits_ai_graphics_note; }
test_store_menu_shows_licences()         { run_gd test_credits.gd test_menu_shows_licences_item; }
test_store_open_credits()                { run_gd test_credits.gd test_open_credits_from_menu; }
test_store_credits_scroll()              { run_gd test_credits.gd test_credits_scroll_by_actions; }
test_store_credits_back()                { run_gd test_credits.gd test_credits_back_returns_to_menu; }
test_store_credits_by_touch()            { run_gd test_credits.gd test_credits_by_touch; }

# ------------------------------------------------------------ Info.plist i privacy manifest

_export_xcode() {
	rm -rf "$XCODE_EXPORT"
	EXPORT_LOG=$("$ROOT/build.sh" ios-xcode 2>&1)
	EXPORT_RC=$?
}

test_store_presets_declare_controller_support() {
	local p v
	for p in "iOS" "iOS Xcode"; do
		v=$(preset_value "$IOS_PRESETS" "$p" application/additional_plist_content)
		assert_contains "$v" "GCSupportsControllerUserInteraction" "$p: additional_plist_content declares controller support" || return 1
		assert_contains "$v" "ExtendedGamepad" "$p: additional_plist_content lists ExtendedGamepad" || return 1
	done
}

test_store_info_plist_controller_keys() {
	_export_xcode
	assert_eq 0 "$EXPORT_RC" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$EXPORT_LOG")" || return 1
	local plist="$XCODE_EXPORT/PHOBOS/PHOBOS-Info.plist"
	plutil -lint "$plist" >/dev/null || fail "Info.plist is not valid" || return 1
	assert_eq "true" "$(plutil -extract GCSupportsControllerUserInteraction raw -o - "$plist" 2>&1)" "GCSupportsControllerUserInteraction = true (App Store: controller support)" || return 1
	assert_eq '[{"ProfileName":"ExtendedGamepad"}]' "$(plutil -extract GCSupportedGameControllers json -o - "$plist" 2>&1)" "GCSupportedGameControllers = ExtendedGamepad" || return 1
	assert_eq "false" "$(plutil -extract ITSAppUsesNonExemptEncryption raw -o - "$plist")" "export compliance unchanged"
}

# characterization: what Godot 4.7 already generates must stay
test_store_privacy_manifest_and_display_name() {
	_export_xcode
	assert_eq 0 "$EXPORT_RC" "build.sh ios-xcode exit code" || return 1
	local m="$XCODE_EXPORT/PrivacyInfo.xcprivacy"
	assert_file "$m" || return 1
	assert_eq "false" "$(plutil -extract NSPrivacyTracking raw -o - "$m")" "privacy manifest: no tracking" || return 1
	local collected; collected=$(plutil -extract NSPrivacyCollectedDataTypes json -o - "$m" 2>/dev/null || echo "[]")
	assert_eq "[]" "$collected" "privacy manifest: no collected data types (Data Not Collected)" || return 1
	local domains; domains=$(plutil -extract NSPrivacyTrackingDomains json -o - "$m" 2>/dev/null || echo "[]")
	assert_eq "[]" "$domains" "privacy manifest: no tracking domains" || return 1
	assert_contains "$(plutil -extract NSPrivacyAccessedAPITypes json -o - "$m")" "NSPrivacyAccessedAPICategoryFileTimestamp" "required-reason API declared by Godot" || return 1
	assert_contains "$(cat "$XCODE_EXPORT/PHOBOS.xcodeproj/project.pbxproj")" 'INFOPLIST_KEY_CFBundleDisplayName = "PHOBOS";' "name under the icon stays PHOBOS"
}

# ------------------------------------------------------------ materiały App Store Connect

# _md_section <file> <heading> — text under "## <heading>" up to the next "## ", trimmed.
_md_section() {
	python3 -I - "$1" "$2" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^## ' + re.escape(sys.argv[2]) + r'[ \t]*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
print(m.group(1).strip() if m else "<missing>", end="")
PY
}

_len() { python3 -I -c 'import sys; print(len(sys.argv[1]))' "$1"; }

# _check_limit <file> <heading> <max chars>
_check_limit() {
	local v n; v=$(_md_section "$1" "$2")
	[[ "$v" != "<missing>" && -n "$v" ]] || fail "${1##*/}: section '## $2' missing or empty" || return 1
	n=$(_len "$v")
	(( n <= $3 )) || fail "${1##*/}: '$2' has $n chars (max $3)"
}

_check_metadata() { # file
	local f=$1
	assert_file "$f" || return 1
	_check_limit "$f" "Name" 30 || return 1
	_check_limit "$f" "Subtitle" 30 || return 1
	_check_limit "$f" "Promotional Text" 170 || return 1
	_check_limit "$f" "Description" 4000 || return 1
	_check_limit "$f" "Keywords" 100 || return 1
	_check_limit "$f" "What's New" 4000 || return 1
	assert_eq "$APP_NAME" "$(_md_section "$f" "Name")" "${f##*/}: store name" || return 1
	local kw; kw=$(_md_section "$f" "Keywords")
	assert_not_contains "$kw" ", " "${f##*/}: keywords separated by commas without spaces" || return 1
	assert_not_contains "$(tr '[:upper:]' '[:lower:]' <<<"$kw")" "phobos" "${f##*/}: keywords do not repeat the app name" || return 1
	local all; all=$(cat "$f")
	local word
	for word in Android "Google Play" Steam Windows PlayStation PS5 macOS Amiga C64 "Commodore"; do
		assert_not_contains "$all" "$word" "${f##*/}: no other platforms (guideline 2.3.10)" || return 1
	done
}

test_store_metadata_pl() {
	_check_metadata "$RELEASE/metadata-pl.md" || return 1
	local d; d=$(_md_section "$RELEASE/metadata-pl.md" "Description")
	assert_contains "$d" "dotyk" "PL description mentions touch controls" || return 1
	assert_contains "$d" "kontroler" "PL description mentions game controllers"
}

test_store_metadata_en() {
	_check_metadata "$RELEASE/metadata-en.md" || return 1
	local d; d=$(_md_section "$RELEASE/metadata-en.md" "Description")
	assert_contains "$d" "touch" "EN description mentions touch controls" || return 1
	assert_contains "$d" "controller" "EN description mentions game controllers"
}

test_store_privacy_policy() {
	local f="$RELEASE/privacy-policy.md"
	assert_file "$f" || return 1
	local pl en; pl=$(_md_section "$f" "Polski"); en=$(_md_section "$f" "English")
	[[ "$pl" != "<missing>" ]] || fail "privacy-policy.md: section '## Polski' missing" || return 1
	[[ "$en" != "<missing>" ]] || fail "privacy-policy.md: section '## English' missing" || return 1
	assert_contains "$pl" "nie zbiera" "PL: states that no data is collected" || return 1
	assert_contains "$en" "does not collect" "EN: states that no data is collected" || return 1
	assert_contains "$pl" "ranking" "PL: local leaderboard explained" || return 1
	assert_contains "$en" "leaderboard" "EN: local leaderboard explained" || return 1
	assert_contains "$en" "tracking" "EN: no tracking stated" || return 1
	grep -Eq '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' "$f" || fail "privacy-policy.md: contact e-mail" || return 1
	grep -Eq '2026-[0-9]{2}-[0-9]{2}' "$f" || fail "privacy-policy.md: effective date (YYYY-MM-DD)"
}

test_store_connect_checklist() {
	local f="$RELEASE/app-store-connect-checklist.md"
	assert_file "$f" || return 1
	local s; s=$(cat "$f")
	local h
	for h in "## App Information" "## Pricing and Availability" "## App Privacy" "## Age Rating" \
		"## Export Compliance" "## Digital Services Act" "## Game Controllers" "## Version Information" "## URLs"; do
		assert_contains "$s" "$h" "checklist section" || return 1
	done
	assert_contains "$s" "$APP_NAME" "store name" || return 1
	assert_contains "$s" "com.marek.piotrowski.phobos" "bundle id" || return 1
	assert_contains "$s" "Data Not Collected" "privacy answer" || return 1
	assert_contains "$s" "Free" "price" || return 1
	assert_contains "$s" "non-trader" "DSA status" || return 1
	assert_contains "$s" "ITSAppUsesNonExemptEncryption" "export compliance" || return 1
	assert_contains "$s" "Game Controller Required" "controllers optional (do not tick Required)" || return 1
	local urls; urls=$(_md_section "$f" "URLs")
	grep -Eq 'Support URL: https://[^ ]+' <<<"$urls" || fail "checklist: Support URL: https://…" || return 1
	grep -Eq 'Privacy Policy URL: https://[^ ]+' <<<"$urls" || fail "checklist: Privacy Policy URL: https://…"
}

test_store_screenshots_guide() {
	local f="$RELEASE/screenshots.md"
	assert_file "$f" || return 1
	grep -Eq '2868 ?[x×] ?1320' "$f" || fail "screenshots.md: iPhone 6.9\" landscape 2868×1320" || return 1
	grep -Eq '2752 ?[x×] ?2064|2732 ?[x×] ?2048' "$f" || fail "screenshots.md: iPad 13\" landscape size" || return 1
	assert_contains "$(cat "$f")" "xcrun simctl io booted screenshot" "screenshots.md: how to capture in the simulator"
}
