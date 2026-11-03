ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(ROOT)/build
TOOLCHAIN_DIR := $(ROOT)/.toolchain
CC := $(TOOLCHAIN_DIR)/bin/m68k-amigaos-gcc
SIZE := $(TOOLCHAIN_DIR)/bin/m68k-amigaos-size
AMITOOLS_VERSION := 0.8.1
XDFTOOL := uv tool run --from amitools==$(AMITOOLS_VERSION) xdftool
CFLAGS := -m68000 -O2 -fomit-frame-pointer -Wall -Wextra -Werror
ASSET_TOOL := env DYLD_FALLBACK_LIBRARY_PATH=$(shell brew --prefix)/lib uv run --with pillow==11.3.0 --with cairosvg==2.8.2 python
ASSET_SOURCES := $(wildcard $(ROOT)/../../project/assets/sprites/player/*.png) $(wildcard $(ROOT)/../../project/assets/sprites/enemy/*.png) $(wildcard $(ROOT)/../../project/assets/sprites/pickups/*.svg) $(wildcard $(ROOT)/../../project/assets/sprites/effects/*.svg) $(ROOT)/../../project/assets/sprites/arena/arena_floor.svg $(ROOT)/../../project/assets/fonts/Tektur-Variable.ttf $(ROOT)/../../project/assets/fonts/Oxanium-Variable.ttf
GENERATED_ASSETS := $(ROOT)/assets/generated/assets.h $(ROOT)/assets/generated/assets_data.c $(ROOT)/assets/generated/assets.s $(ROOT)/assets/generated/gfx.lz $(ROOT)/assets/generated/sfx.raw $(ROOT)/assets/generated/music.ima $(ROOT)/assets/generated/manifest.json
SOURCES := $(ROOT)/src/main.c $(ROOT)/src/game.c $(ROOT)/src/hw.c $(ROOT)/src/render.c $(ROOT)/src/text.c $(ROOT)/src/audio.c $(ROOT)/src/scores.c $(ROOT)/src/debug.c $(ROOT)/src/assets_load.c $(ROOT)/src/vblank.s $(ROOT)/assets/generated/assets_data.c $(ROOT)/assets/generated/assets.s
PROGRAM := $(BUILD_DIR)/PHOBOS
ADF := $(BUILD_DIR)/PHOBOS-A500.adf

.PHONY: all bootstrap clean emulator verify demo

all: $(ADF)

bootstrap:
	$(ROOT)/tools/bootstrap_toolchain.sh

$(ROOT)/assets/generated/manifest.json: $(ROOT)/tools/convert_assets.py $(ASSET_SOURCES)
	$(ASSET_TOOL) $(ROOT)/tools/convert_assets.py

$(filter-out %/manifest.json,$(GENERATED_ASSETS)): $(ROOT)/assets/generated/manifest.json
	@test -f $@

$(PROGRAM): $(SOURCES) $(GENERATED_ASSETS)
	@mkdir -p $(BUILD_DIR)
	@test -x $(CC) || { printf '%s\n' "Brak toolchainu. Uruchom: make bootstrap"; exit 1; }
	$(CC) $(CFLAGS) -Wa,-I$(ROOT)/assets/generated -o $@ $(SOURCES) -lamiga -mcrt=nix13
	$(SIZE) $@

$(ADF): $(PROGRAM) $(ROOT)/disk/S/startup-sequence
	@mkdir -p $(BUILD_DIR)
	@rm -f $@
	$(XDFTOOL) $@ format PHOBOS ofs + boot install boot1x + makedir S + makedir LICENSES + write $(ROOT)/disk/S/startup-sequence S/startup-sequence + write $(PROGRAM) PHOBOS + write $(ROOT)/../../project/assets/fonts/OFL-Tektur.txt LICENSES/OFL-TEKTUR.TXT + write $(ROOT)/../../project/assets/fonts/OFL-Oxanium.txt LICENSES/OFL-OXANIUM.TXT + protect PHOBOS rwed
	$(XDFTOOL) $@ time S "01.01.2000 00:00:00"
	$(XDFTOOL) $@ time S/startup-sequence "01.01.2000 00:00:00"
	$(XDFTOOL) $@ time PHOBOS "01.01.2000 00:00:00"
	$(XDFTOOL) $@ time LICENSES "01.01.2000 00:00:00"
	$(XDFTOOL) $@ time LICENSES/OFL-TEKTUR.TXT "01.01.2000 00:00:00"
	$(XDFTOOL) $@ time LICENSES/OFL-OXANIUM.TXT "01.01.2000 00:00:00"
	$(XDFTOOL) $@ root create_time "01.01.2000 00:00:00"
	$(XDFTOOL) $@ root disk_time "01.01.2000 00:00:00"
	$(XDFTOOL) $@ root time "01.01.2000 00:00:00"

emulator: $(ADF)
	$(ROOT)/tools/run_emulator.sh

demo: $(PROGRAM)
	$(ROOT)/tools/run_demo.sh

verify: $(ADF)
	$(ROOT)/tests/verify.sh

clean:
	@rm -rf $(BUILD_DIR)
