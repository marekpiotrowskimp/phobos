#!/usr/bin/env bash
# Shared helpers for the iOS port tests. Sourced by run_tests.sh before each test file.

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
IOS_DIR="$ROOT/ports/ios"
IOS_PROJECT="$IOS_DIR/project"
IOS_PRESETS="$IOS_PROJECT/export_presets.cfg"
MACOS_PRESETS="$ROOT/project/export_presets.cfg"
XCODE_EXPORT="$IOS_PROJECT/build/xcode"

SKIP=77

fail() { printf '    assertion failed: %s\n' "$*" >&2; return 1; }

assert_eq() { # expected actual message
	[[ "$1" == "$2" ]] || fail "$3"$'\n'"      expected: $(printf '%q' "$1")"$'\n'"      actual:   $(printf '%q' "$2")"
}

assert_contains() { # haystack needle message
	[[ "$1" == *"$2"* ]] || fail "$3 (missing: $2)"
}

assert_not_contains() { # haystack needle message
	[[ "$1" != *"$2"* ]] || fail "$3 (unexpected: $2)"
}

assert_file() { [[ -f "$1" ]] || fail "missing file: ${1#"$ROOT"/}"; }
assert_dir() { [[ -d "$1" ]] || fail "missing directory: ${1#"$ROOT"/}"; }

# preset_names <export_presets.cfg> — one preset name per line, in file order.
preset_names() {
	python3 -I - "$1" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for section, body in re.findall(r'^\[(preset\.\d+)\]\n(.*?)(?=^\[|\Z)', text, re.M | re.S):
    m = re.search(r'^name="(.*)"$', body, re.M)
    print(m.group(1) if m else "")
EOF
}

# preset_value <export_presets.cfg> <preset name> <key> — raw value (quotes kept) or
# the literal string <missing>. Looks in [preset.N] and [preset.N.options].
preset_value() {
	python3 -I - "$1" "$2" "$3" <<'EOF'
import re, sys
path, name, key = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
sections = dict(re.findall(r'^\[([^\]]+)\]\n(.*?)(?=^\[|\Z)', text, re.M | re.S))
for sec, body in sections.items():
    if re.fullmatch(r'preset\.\d+', sec) and re.search(r'^name="%s"$' % re.escape(name), body, re.M):
        for part in (body, sections.get(sec + ".options", "")):
            m = re.search(r'^%s=(.*)$' % re.escape(key), part, re.M)
            if m:
                print(m.group(1)); sys.exit(0)
print("<missing>")
EOF
}

baseline_commit() { { tr -d '[:space:]' < "$IOS_DIR/BASELINE"; } 2>/dev/null; }
