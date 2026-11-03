# PHOBOS

A twin-stick survival shooter inspired by the classic Alien Phobia (1997).

## Running (development)

```sh
godot --path project --editor
```

## Controls

| Action | Gamepad (DualSense) | Keyboard |
|--------|---------------------|----------|
| Move | left stick | WASD / arrows |
| Aim | right stick | mouse |
| Fire | R2 (hold) | LMB / Space |
| Pause | START | Esc |
| Restart | A | Enter / Space |

## macOS build

```sh
cd project
godot --headless --export-release "macOS" build/PHOBOS.app
```

If Gatekeeper blocks the app:

```sh
xattr -dr com.apple.quarantine build/PHOBOS.app
```

## Project rule

If after a week you catch yourself launching it just for fun — the project makes sense.
