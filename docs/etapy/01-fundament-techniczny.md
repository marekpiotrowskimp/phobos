# Etap 1 — Fundament techniczny

## Cel

Postawić działający projekt Godot: pusta arena greybox, kamera, konfiguracja wejścia (pad + klawiatura), eksport na macOS i weryfikacja wydajności.

## Zakres

- Projekt Godot 4.x, renderer Forward+, główne sceny (`main`, `player`, `arena`).
- Arena greybox: prostokątna, czytelne obrysy i oświetlenie, przyciemnione otoczenie.
- Kamera: stała, top-down, arena w całości na ekranie (16:9).
- Input Map: `move` (lewa gałka/WASD), `aim` (prawa gałka/klawiatura), `shoot` (R2/lewy przycisk myszy).
- DualSense wykrywany jako pad; fallback klawiatura.
- Eksport Preset macOS (arm64, uniwersalny) → build `.app`.
- Pętla gry: stały krok 60 Hz (Physics Ticks), cel 60 FPS.

## Rezultat dla gracza

Otwiera build `.app`, widzi oświetloną arenę z zarysem postaci, a postać rusza się gałką na padzie.

## Kryteria akceptacji

- [x] Walidacja projektu Godot w trybie headless przechodzi bez błędów.
- [x] Postać porusza się padem (DualSense) i klawiaturą.
- [x] Arena mieści się w całości w rzucie kamery 16:9.
- [x] Build `.app` uruchamia się z Docka/Findera bez terminala.
- [x] FPS ≥ 60 na pustej arenie (pomiar w grze).

## Testowanie

- Uruchomienie z edytora (F5) i z builda.
- Ruch padem + klawiaturą; próba odłączenia/wyłączenia pada.
- Pomiar FPS oknem debug.

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| DualSense nie widziany przez Godot | Check Input Map, `--verbose` log, restart pada, fallback klawiatura |
| Eksport macOS blokowany przez Gatekeeper | `xattr -dr com.apple.quarantine` na build; podpisywanie ad-hoc |

## Poza zakresem

Mechanika strzelania, wrogowie, HUD, audio — kolejne etapy.
