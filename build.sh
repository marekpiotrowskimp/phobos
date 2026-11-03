#!/usr/bin/env bash
# PHOBOS — builds the macOS (Godot) version and the Amiga 500 port.
# Missing tools are installed automatically (Homebrew, Godot, export templates, uv, Amiga toolchain).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="$ROOT/project"
AMIGA_DIR="$ROOT/ports/amiga500"
MACOS_APP="$PROJECT_DIR/build/PHOBOS.app"
AMIGA_ADF="$AMIGA_DIR/build/PHOBOS-A500.adf"

if [[ -t 1 ]]; then
	C_INFO=$'\033[1;34m' C_OK=$'\033[1;32m' C_WARN=$'\033[1;33m' C_ERR=$'\033[1;31m' C_OFF=$'\033[0m'
else
	C_INFO='' C_OK='' C_WARN='' C_ERR='' C_OFF=''
fi

log()  { printf '%s==>%s %s\n' "$C_INFO" "$C_OFF" "$*"; }
ok()   { printf '%s✔%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()  { printf '%s✘%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: ./build.sh [target]

Targets:
  all     (default) build both platforms
  macos   Godot export   → project/build/PHOBOS.app
  amiga   Amiga 500 port → ports/amiga500/build/PHOBOS-A500.adf
  clean   remove build outputs of both platforms
  -h      show this help

Missing tools are installed automatically via Homebrew.
EOF
}

# ---------------------------------------------------------------- common tools

ensure_macos() {
	[[ "$(uname -s)" == "Darwin" ]] || die "This script supports macOS only."
}

ensure_xcode_clt() {
	if ! xcode-select -p >/dev/null 2>&1; then
		warn "Xcode Command Line Tools are missing — starting the installer."
		xcode-select --install || true
		die "Finish the Command Line Tools installation in the dialog, then run ./build.sh again."
	fi
}

ensure_brew() {
	if command -v brew >/dev/null 2>&1; then
		return
	fi
	for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [[ -x "$candidate" ]]; then
			eval "$("$candidate" shellenv)"
			return
		fi
	done
	log "Installing Homebrew…"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		if [[ -x "$candidate" ]]; then
			eval "$("$candidate" shellenv)"
			return
		fi
	done
	die "Homebrew installation failed."
}

# ---------------------------------------------------------------- macOS (Godot)

ensure_godot() {
	if ! command -v godot >/dev/null 2>&1; then
		log "Installing Godot (brew cask)…"
		brew install --cask godot
		command -v godot >/dev/null 2>&1 || die "Godot was installed but 'godot' is not on PATH."
	fi
}

# "4.7.1.stable.official.a13da4feb" -> "4.7.1.stable"
godot_version() {
	godot --version | head -n1 | awk -F. '{
		for (i = 1; i <= NF; i++) {
			printf "%s%s", (i > 1 ? "." : ""), $i
			if ($i !~ /^[0-9]+$/) break
		}
	}'
}

ensure_export_templates() {
	local version templates_dir number status tag url tmp
	version=$(godot_version)
	[[ -n "$version" ]] || die "Could not detect the Godot version."
	templates_dir="$HOME/Library/Application Support/Godot/export_templates/$version"

	if [[ -f "$templates_dir/macos.zip" ]]; then
		return
	fi

	number=${version%.*}
	status=${version##*.}
	tag="$number-$status"
	url="https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"

	log "Downloading Godot $tag export templates…"
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' RETURN
	curl -fL --progress-bar -o "$tmp/templates.tpz" "$url" || die "Download failed: $url"
	unzip -q "$tmp/templates.tpz" -d "$tmp"
	mkdir -p "$templates_dir"
	cp -R "$tmp/templates/." "$templates_dir/"
	ok "Export templates installed in $templates_dir"
}

build_macos() {
	log "macOS build (Godot)"
	ensure_godot
	ensure_export_templates

	if [[ ! -d "$PROJECT_DIR/.godot" ]]; then
		log "First run — importing project assets…"
		godot --headless --path "$PROJECT_DIR" --import
	fi

	mkdir -p "$PROJECT_DIR/build"
	godot --headless --path "$PROJECT_DIR" --export-release "macOS" build/PHOBOS.app
	[[ -d "$MACOS_APP" ]] || die "Export failed — $MACOS_APP is missing."
	xattr -dr com.apple.quarantine "$MACOS_APP" 2>/dev/null || true
	ok "macOS: $MACOS_APP"
}

# ---------------------------------------------------------------- Amiga 500

ensure_uv() {
	if ! command -v uv >/dev/null 2>&1; then
		log "Installing uv…"
		brew install uv
	fi
}

build_amiga() {
	log "Amiga 500 build"
	ensure_uv

	if ! brew bundle check --file="$AMIGA_DIR/Brewfile" >/dev/null 2>&1; then
		log "Installing dependencies from ports/amiga500/Brewfile…"
		brew bundle --file="$AMIGA_DIR/Brewfile"
	fi

	if [[ ! -f "$AMIGA_DIR/.toolchain/.bootstrap-done" ]]; then
		warn "m68k-amigaos toolchain is missing or incomplete — building it from source (this can take a long time)."
		make -C "$AMIGA_DIR" bootstrap
	fi

	make -C "$AMIGA_DIR"
	[[ -f "$AMIGA_ADF" ]] || die "Build failed — $AMIGA_ADF is missing."
	ok "Amiga 500: $AMIGA_ADF"
}

# ---------------------------------------------------------------- main

clean() {
	log "Cleaning build outputs"
	rm -rf "$PROJECT_DIR/build"
	make -C "$AMIGA_DIR" clean
	ok "Clean"
}

main() {
	local target=${1:-all}
	case "$target" in
		-h|--help|help) usage; return ;;
		clean) clean; return ;;
		all|macos|amiga) ;;
		*) usage >&2; die "Unknown target: $target" ;;
	esac

	ensure_macos
	ensure_xcode_clt
	ensure_brew

	case "$target" in
		macos) build_macos ;;
		amiga) build_amiga ;;
		all)   build_macos; build_amiga ;;
	esac

	printf '\n'
	ok "Done."
	[[ "$target" != amiga ]] && printf '   macOS:     %s\n' "$MACOS_APP"
	[[ "$target" != macos ]] && printf '   Amiga 500: %s\n' "$AMIGA_ADF"
	return 0
}

main "$@"
