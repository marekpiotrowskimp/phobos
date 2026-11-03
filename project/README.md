# PHOBOS

Twin-stick survival shooter inspirowany klasyką Alien Phobia (1997).

## Uruchomienie (dev)

```sh
godot --path project --editor
```

## Sterowanie

| Akcja | Pad (DualSense) | Klawiatura |
|-------|-----------------|------------|
| Ruch | lewa gałka | WASD / strzałki |
| Celowanie | prawa gałka | mysz |
| Strzał | R2 (trzymaj) | LPM / Spacja |
| Pauza | START | Esc |
| Restart | A | Enter / Spacja |

## Build macOS

```sh
cd project
godot --headless --export-release "macOS" build/PHOBOS.app
```

Jeśli Gatekeeper blokuje uruchomienie:

```sh
xattr -dr com.apple.quarantine build/PHOBOS.app
```

## Zasada projektu

Jeśli po tygodniu łapiesz się na tym, że odpalasz to dla przyjemności — projekt ma sens.
