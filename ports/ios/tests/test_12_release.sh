#!/usr/bin/env bash
# Etap 05 — build wydania i materiały: numer wersji/buildu (tools/set_version.sh), rozmiar
# paczki, instrukcje dla użytkownika (wysyłka, TestFlight, App Review, wydanie).
# Wysyłkę, TestFlight i publikację wykonuje użytkownik (decyzja nr 7 z etapu 00).

RELEASE="$IOS_DIR/release"
SET_VERSION="$IOS_DIR/tools/set_version.sh"

macos_short_version() { preset_value "$MACOS_PRESETS" macOS application/short_version | tr -d '"'; }

# Runs set_version.sh on a scratch copy of the iOS presets; sets OUT, RC, COPY.
_run_set_version() {
	COPY=$(mktemp -d)/export_presets.cfg
	cp "$IOS_PRESETS" "$COPY"
	OUT=$("$SET_VERSION" --presets "$COPY" "$@" 2>&1)
	RC=$?
}

# ------------------------------------------------------------ wersja i build

# characterization: the store version follows the macOS version
test_release_short_version_matches_macos() {
	local mac; mac=$(macos_short_version)
	[[ -n "$mac" ]] || fail "macOS short_version missing" || return 1
	local p
	for p in "iOS" "iOS Xcode"; do
		assert_eq "\"$mac\"" "$(preset_value "$IOS_PRESETS" "$p" application/short_version)" "$p: short_version = macOS ($mac)" || return 1
	done
}

test_release_build_number_is_integer() {
	local a b
	a=$(preset_value "$IOS_PRESETS" "iOS" application/version | tr -d '"')
	b=$(preset_value "$IOS_PRESETS" "iOS Xcode" application/version | tr -d '"')
	[[ "$a" =~ ^[1-9][0-9]*$ ]] || fail "iOS: build number (application/version) must be a positive integer, got '$a'" || return 1
	assert_eq "$a" "$b" "both presets share the build number"
}

test_release_set_version_updates_both_presets() {
	assert_file "$SET_VERSION" || return 1
	local mac; mac=$(macos_short_version)
	_run_set_version "$mac" 41
	assert_eq 0 "$RC" "set_version.sh $mac 41 exit code"$'\n'"$OUT" || return 1
	local p
	for p in "iOS" "iOS Xcode"; do
		assert_eq "\"$mac\"" "$(preset_value "$COPY" "$p" application/short_version)" "$p: short_version" || return 1
		assert_eq '"41"' "$(preset_value "$COPY" "$p" application/version)" "$p: build number" || return 1
	done
	assert_contains "$OUT" "$mac (41)" "prints the new version (build)" || return 1
	local other
	other=$(diff <(grep -v '^application/\(short_\)\{0,1\}version=' "$IOS_PRESETS") <(grep -v '^application/\(short_\)\{0,1\}version=' "$COPY"))
	assert_eq "" "$other" "nothing else in the presets changes"
}

test_release_set_version_requires_higher_build() {
	assert_file "$SET_VERSION" || return 1
	local mac; mac=$(macos_short_version)
	_run_set_version "$mac" 41 || true
	local copy=$COPY
	OUT=$("$SET_VERSION" --presets "$copy" "$mac" 41 2>&1); RC=$?
	assert_eq 1 "$RC" "same build number again is rejected (App Store needs a higher build)" || return 1
	assert_contains "$OUT" "41" "message names the current build" || return 1
	OUT=$("$SET_VERSION" --presets "$copy" "$mac" 40 2>&1); RC=$?
	assert_eq 1 "$RC" "lower build number is rejected" || return 1
	assert_eq '"41"' "$(preset_value "$copy" "iOS" application/version)" "rejected call leaves the presets unchanged" || return 1
	OUT=$("$SET_VERSION" --presets "$copy" "$mac" 42 2>&1); RC=$?
	assert_eq 0 "$RC" "higher build accepted"
}

test_release_set_version_validates_input() {
	assert_file "$SET_VERSION" || return 1
	local mac; mac=$(macos_short_version)
	_run_set_version "$mac" abc
	assert_eq 1 "$RC" "non-numeric build rejected" || return 1
	_run_set_version 1.0 7
	assert_eq 1 "$RC" "version must be X.Y.Z" || return 1
	_run_set_version 9.9.9 7
	assert_eq 1 "$RC" "version different from macOS rejected" || return 1
	assert_contains "$OUT" "$mac" "message names the macOS version" || return 1
	assert_eq "$(preset_value "$IOS_PRESETS" iOS application/version)" "$(preset_value "$COPY" iOS application/version)" "rejected call leaves the presets unchanged" || return 1
	_run_set_version
	assert_eq 1 "$RC" "no arguments → usage + exit 1" || return 1
	assert_contains "$OUT" "set_version.sh" "usage text"
}

test_release_export_carries_version() {
	rm -rf "$XCODE_EXPORT"
	local log rc
	log=$("$ROOT/build.sh" ios-xcode 2>&1); rc=$?
	assert_eq 0 "$rc" "build.sh ios-xcode exit code"$'\n'"$(tail -20 <<<"$log")" || return 1
	local pbx; pbx=$(cat "$XCODE_EXPORT/PHOBOS.xcodeproj/project.pbxproj")
	local short build
	short=$(preset_value "$IOS_PRESETS" "iOS Xcode" application/short_version | tr -d '"')
	build=$(preset_value "$IOS_PRESETS" "iOS Xcode" application/version | tr -d '"')
	assert_contains "$pbx" "MARKETING_VERSION = $short;" "CFBundleShortVersionString from the preset" || return 1
	assert_contains "$pbx" "CURRENT_PROJECT_VERSION = $build;" "CFBundleVersion (build) from the preset" || return 1
	# characterization: game data stays small (the engine library dominates the app size)
	local pck_size; pck_size=$(stat -f %z "$XCODE_EXPORT/PHOBOS.pck")
	(( pck_size < 10 * 1024 * 1024 )) || fail "PHOBOS.pck is $pck_size bytes (limit 10 MB)"
}

test_release_ipa_size() {
	[[ "${PHOBOS_IOS_SIGNED:-}" == 1 ]] || return $SKIP
	local ipa="$IOS_PROJECT/build/PHOBOS.ipa"
	"$ROOT/build.sh" ios >/dev/null 2>&1 || fail "build.sh ios failed" || return 1
	local size; size=$(stat -f %z "$ipa")
	(( size < 100 * 1024 * 1024 )) || fail "PHOBOS.ipa is $size bytes (target < 100 MB)"
}

# ------------------------------------------------------------ materiały dla użytkownika

# _require_sections <file> <heading>… — every "## heading" present and non-empty
_require_sections() {
	local f=$1; shift
	assert_file "$f" || return 1
	local h body
	for h in "$@"; do
		body=$(python3 -I - "$f" "$h" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^## ' + re.escape(sys.argv[2]) + r'[ \t]*\n(.*?)(?=^## |\Z)', t, re.M | re.S)
print(m.group(1).strip() if m else "<missing>", end="")
PY
)
		[[ "$body" != "<missing>" && -n "$body" ]] || fail "${f##*/}: section '## $h' missing or empty" || return 1
	done
}

test_release_guide() {
	local f="$RELEASE/release-guide.md"
	_require_sections "$f" "1. Wersja i build" "2. Build" "3. Wysyłka" "4. TestFlight" "5. App Review" "6. Wydanie" "Po odrzuceniu" || return 1
	local s; s=$(cat "$f")
	assert_contains "$s" "ports/ios/tools/set_version.sh" "guide: how to bump the build" || return 1
	assert_contains "$s" "./build.sh ios" "guide: build command" || return 1
	assert_contains "$s" "PHOBOS.ipa" "guide: artefact" || return 1
	assert_contains "$s" "Transporter" "guide: upload with Transporter" || return 1
	assert_contains "$s" "Organizer" "guide: or with Xcode Organizer" || return 1
	assert_contains "$s" "review-notes.md" "guide: points to review notes" || return 1
	assert_contains "$s" "release-checklist.md" "guide: points to the checklist" || return 1
	assert_contains "$s" "main" "guide: merge to main before review (policy URLs)"
}

test_release_review_notes() {
	local f="$RELEASE/review-notes.md"
	_require_sections "$f" "Notes for App Review" || return 1
	local s; s=$(cat "$f")
	assert_contains "$s" "touch" "explains touch controls" || return 1
	assert_contains "$s" "optional" "controller is optional" || return 1
	assert_contains "$s" "No account" "no sign-in needed" || return 1
	assert_contains "$s" "LICENCJE" "where the licences screen is" || return 1
	assert_contains "$s" "offline" "no network" || return 1
	local n; n=$(python3 -I -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$f")
	(( n <= 4000 )) || fail "review-notes.md has $n chars (App Review notes max 4000)"
}

test_release_checklist() {
	local f="$RELEASE/release-checklist.md"
	assert_file "$f" || return 1
	local s; s=$(cat "$f")
	local count; count=$(grep -c '^- \[ \]' "$f")
	(( count >= 10 )) || fail "release-checklist.md: at least 10 checkbox items (got $count)" || return 1
	local item
	for item in "set_version.sh" "bash ports/ios/tests/run_tests.sh" "./build.sh macos" "main" \
		"curl" "privacy-policy.md" "support.md" "app-store-connect-checklist.md" "screenshots.md" \
		"test-report.md" "Game Controller Required"; do
		assert_contains "$s" "$item" "release-checklist.md mentions" || return 1
	done
}

test_release_test_report_template() {
	local f="$RELEASE/test-report.md"
	_require_sections "$f" "Build" "Urządzenia" "Testy funkcjonalne" "Wydajność" "Regresja macOS" "Decyzja" || return 1
	local s; s=$(cat "$f")
	local item
	for item in "45" "60 FPS" "≤ 3 s" "15 min" "LICENCJE" "TestFlight" "połączenie" "ranking" "100 MB"; do
		assert_contains "$s" "$item" "test-report.md covers" || return 1
	done
}
