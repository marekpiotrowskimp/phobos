# PHOBOS

Twin-stick survival shooter (Godot) z portami na **Amigę 500** i **Commodore 64**.

| Katalog | Zawartość |
|---|---|
| [`project/`](project/) | Wersja główna — Godot 4, macOS. Sterowanie i build: [project/README.md](project/README.md) |
| [`ports/amiga500/`](ports/amiga500/) | Port na Amigę 500 (C, toolchain m68k-amigaos, `Makefile`, `toolchain.lock`) |
| [`ports/commodore64/`](ports/commodore64/) | Dokumentacja portu na C64 |
| [`docs/`](docs/) | Projekt gry |

## Szybki start

```sh
godot --path project --editor
```

Port Amigi: zależności w `ports/amiga500/Brewfile`, build `make -C ports/amiga500`.
