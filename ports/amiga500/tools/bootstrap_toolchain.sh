#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/toolchain.lock"

PREFIX="$ROOT/.toolchain"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/Library/Caches}/phobos-amiga500"
SOURCE_DIR="$CACHE_ROOT/m68k-amigaos-gcc"

# Written only after the whole toolchain (gcc + libraries) is installed;
# a bare m68k-amigaos-gcc binary may be left over from an interrupted build.
STAMP="$PREFIX/.bootstrap-done"

if [[ -f "$STAMP" && -x "$PREFIX/bin/m68k-amigaos-gcc" ]]; then
	"$PREFIX/bin/m68k-amigaos-gcc" --version
	exit 0
fi

command -v brew >/dev/null
command -v git >/dev/null
command -v xcrun >/dev/null

brew bundle --file "$ROOT/Brewfile"

mkdir -p "$CACHE_ROOT"
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
	git clone "$AMIGA_GCC_REPOSITORY" "$SOURCE_DIR"
fi
git -C "$SOURCE_DIR" fetch --depth 1 origin "$AMIGA_GCC_COMMIT"
git -C "$SOURCE_DIR" checkout --detach "$AMIGA_GCC_COMMIT"

# The upstream Makefile clones aros-stuff from master only when it is missing,
# so put the pinned revision in place first.
AROS_DIR="$SOURCE_DIR/projects/aros-stuff"
if [[ ! -d "$AROS_DIR/.git" ]]; then
	mkdir -p "$SOURCE_DIR/projects"
	git clone --filter=blob:none "$AROS_STUFF_REPOSITORY" "$AROS_DIR"
fi
if [[ "$(git -C "$AROS_DIR" rev-parse HEAD)" != "$AROS_STUFF_COMMIT" ]]; then
	git -C "$AROS_DIR" fetch origin "$AROS_STUFF_COMMIT"
	git -C "$AROS_DIR" checkout --detach "$AROS_STUFF_COMMIT"
	# drop any libpthread build made from another revision
	rm -rf "$SOURCE_DIR/build-$(uname -s)-m68k-amigaos/libpthread"
fi

BREW_PREFIX=$(brew --prefix)
SDKROOT=$(xcrun --show-sdk-path)
BUILD_PATH="$PREFIX/bin:$BREW_PREFIX/opt/bison/bin:$BREW_PREFIX/opt/flex/bin:$BREW_PREFIX/opt/make/libexec/gnubin:$BREW_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
JOBS=${JOBS:-$(sysctl -n hw.logicalcpu)}

gcc12_make() {
	env PATH="$BUILD_PATH" \
		CC="$BREW_PREFIX/bin/gcc-12" \
		CXX="$BREW_PREFIX/bin/g++-12" \
		CPP="$BREW_PREFIX/bin/gcc-12 -E -isysroot $SDKROOT" \
		CXXCPP="$BREW_PREFIX/bin/g++-12 -E -isysroot $SDKROOT" \
		CFLAGS="-Os -isysroot $SDKROOT" \
		CXXFLAGS="-Os -isysroot $SDKROOT" \
		gmake -C "$SOURCE_DIR" "$@" PREFIX="$PREFIX" SHELL="$BREW_PREFIX/bin/bash"
}

gcc12_make binutils -j"$JOBS"
# The gcc stage is built serially: under -j its configure intermittently failed
# with conftest files vanishing ("uint64_t or int64_t not found").
gcc12_make gcc -j1

env PATH="$BUILD_PATH" \
	CC="clang" \
	CXX="clang++" \
	CPP="clang -E -isysroot $SDKROOT" \
	CXXCPP="clang++ -E -isysroot $SDKROOT" \
	CFLAGS="-Os -isysroot $SDKROOT" \
	CXXFLAGS="-Os -isysroot $SDKROOT" \
	gmake -C "$SOURCE_DIR" min -j"$JOBS" PREFIX="$PREFIX" SHELL="$BREW_PREFIX/bin/bash"

touch "$STAMP"
"$PREFIX/bin/m68k-amigaos-gcc" --version
