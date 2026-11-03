# PHOBOS

A twin-stick survival shooter made in **Godot**, with ports for the **Amiga 500** and **Commodore 64**.

| Directory | Contents |
|---|---|
| [`project/`](project/) | Main version — Godot 4, macOS |
| [`ports/amiga500/`](ports/amiga500/) | Amiga 500 port (C, m68k-amigaos toolchain, `Makefile`, `toolchain.lock`) |
| [`ports/commodore64/`](ports/commodore64/) | C64 port documentation |
| [`docs/`](docs/) | Game design |

## Controls

| Action | Gamepad (DualSense) | Keyboard |
|---|---|---|
| Move | left stick | WASD / arrows |
| Aim | right stick | mouse |
| Fire | R2 (hold) | LMB / Space |
| Pause | START | Esc |
| Restart | A | Enter / Space |

## Quick build

```sh
./build.sh          # both platforms
./build.sh macos    # project/build/PHOBOS.app
./build.sh amiga    # ports/amiga500/build/PHOBOS-A500.adf
./build.sh clean
```

The script installs any missing tools (Homebrew, Godot, export templates, uv, Brewfile dependencies, the m68k-amigaos toolchain).

## Running (development)

```sh
godot --path project --editor
```

## macOS build

```sh
cd project
godot --headless --export-release "macOS" build/PHOBOS.app
xattr -dr com.apple.quarantine build/PHOBOS.app   # if Gatekeeper blocks the app
```

Amiga port: dependencies in `ports/amiga500/Brewfile`, build with `make -C ports/amiga500`.

## License

MIT — see [LICENSE](LICENSE).
