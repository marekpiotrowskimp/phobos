#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/toolchain.lock"

PREFIX="$ROOT/.toolchain"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/Library/Caches}/phobos-amiga500"
SOURCE_DIR="$CACHE_ROOT/m68k-amigaos-gcc"

if [[ -x "$PREFIX/bin/m68k-amigaos-gcc" ]]; then
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

BREW_PREFIX=$(brew --prefix)
SDKROOT=$(xcrun --show-sdk-path)
BUILD_PATH="$PREFIX/bin:$BREW_PREFIX/opt/bison/bin:$BREW_PREFIX/opt/flex/bin:$BREW_PREFIX/opt/make/libexec/gnubin:$BREW_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
JOBS=${JOBS:-$(sysctl -n hw.logicalcpu)}

env PATH="$BUILD_PATH" \
	CC="$BREW_PREFIX/bin/gcc-12" \
	CXX="$BREW_PREFIX/bin/g++-12" \
	CPP="$BREW_PREFIX/bin/gcc-12 -E -isysroot $SDKROOT" \
	CXXCPP="$BREW_PREFIX/bin/g++-12 -E -isysroot $SDKROOT" \
	CFLAGS="-Os -isysroot $SDKROOT" \
	CXXFLAGS="-Os -isysroot $SDKROOT" \
	gmake binutils gcc -j"$JOBS" PREFIX="$PREFIX" SHELL="$BREW_PREFIX/bin/bash"

env PATH="$BUILD_PATH" \
	CC="clang" \
	CXX="clang++" \
	CPP="clang -E -isysroot $SDKROOT" \
	CXXCPP="clang++ -E -isysroot $SDKROOT" \
	CFLAGS="-Os -isysroot $SDKROOT" \
	CXXFLAGS="-Os -isysroot $SDKROOT" \
	gmake min -j"$JOBS" PREFIX="$PREFIX" SHELL="$BREW_PREFIX/bin/bash"

"$PREFIX/bin/m68k-amigaos-gcc" --version
