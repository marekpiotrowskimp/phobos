# Amiga 500 — założenia i budżet

## Status

`IN_PROGRESS`

Implementacja rozpoczęta na branchu `port/amiga500`. Automatyczna część Etapu 00 działa;
pełne zamknięcie wymaga testu ADF w FS-UAE z legalnym Kickstart 1.3 oraz na prawdziwej A500.

## Target

- Commodore Amiga 500 PAL, chipset OCS.
- 1 MB RAM: 512 KB Chip RAM i 512 KB rozszerzenia.
- Standardowa klawiatura, mysz oraz joystick.
- Dystrybucja jako bootowalny obraz ADF 880 KB.
- Walidacja w emulatorze oraz na prawdziwej Amidze 500.
- Brak wymagania dysku twardego, Fast RAM ponad 512 KB lub akceleratora.

## Zakres etapu

1. Wybrać kompilator, asembler, linker i sposób tworzenia ADF działające na macOS.
2. Porównać `vbcc/vasm`, GCC dla m68k-amigaos i ewentualny lekki framework OCS.
3. Sprawdzić licencje narzędzi i możliwość odtworzenia buildu bez ręcznej konfiguracji IDE.
4. Zbudować minimalny program uruchamiany z ADF w emulatorze i na prawdziwej A500.
5. Zapisać budżet pamięci, czasu klatki, grafiki, audio i rozmiaru obrazu.
6. Zapisać identyfikator drzewa `project/`, który będzie chronioną bazą macOS.

## Wymagania architektury

- Kod portu nie korzysta z Godot, GDScript ani plików `.tscn`.
- Logika gry używa liczb całkowitych lub stałoprzecinkowych.
- Warstwa sprzętowa oddziela wejście, grafikę, audio, czas i zapis od logiki rozgrywki.
- Pamięć gry jest przydzielana statycznie; brak alokacji w głównej pętli.
- Wszystkie bufory Chip RAM mają jawny rozmiar i przeznaczenie.
- Build oraz konwersja zasobów zapisują tylko do `ports/amiga500/`.

## Budżety do zatwierdzenia

| Obszar | Pomiar PoC | Limit końcowy |
|---|---:|---:|
| Chip RAM: ekrany, blity, audio | — | Do ustalenia |
| Pozostała pamięć programu i stanu | — | Do ustalenia |
| Czas logiki w ramce PAL | — | Do ustalenia |
| Czas blittera i odświeżania | — | Do ustalenia |
| Aktywni przeciwnicy | — | Do ustalenia |
| Efekty i pociski/tracery | — | Do ustalenia |
| Minimalny program: text/data/bss | 2120 / 28 / 44 B | Do ustalenia |
| Minimalny program łącznie | 2192 B | Do ustalenia |
| Zajęte miejsce ADF | 8192 B (0,91%) | ≤ 880 KB |

Priorytetem jest responsywne wejście próbkowane w każdej ramce PAL. Docelowe 50 lub 25 klatek
renderowania na sekundę zostanie wybrane po PoC i wymaga akceptacji użytkownika.

## Kryteria zakończenia

- [x] Toolchain instaluje się i buduje projekt na macOS poleceniem `make bootstrap`.
- [x] Minimalny ADF startuje w FS-UAE skonfigurowanym jako PAL A500 1 MB.
- [ ] Ten sam ADF startuje na prawdziwej Amidze 500 1 MB.
- [ ] Powstała tabela budżetów z pomiarami i marginesem bezpieczeństwa.
- [x] Licencje toolchainu nie nakładają ograniczenia „non-commercial” na planowaną dystrybucję.
- [x] Drzewo `project/` nie zostało zmienione.

## Stan techniczny

- Toolchain: `AmigaPorts/m68k-amigaos-gcc` commit `7d3e35f58e61bdf325d84b912b139f973d9b7452`.
- Target kompilatora: Motorola 68000, runtime libnix dla Kickstart 1.3.
- Obraz: OFS `DOS0`, bootblock Workbench 1.x, 901120 bajtów, poprawna suma bootblocku.
- SHA-256 ADF: `6cc6a52dbbfd6e15cbd08081c2cd92112d413e565739ec5cbe373eee96d6ff7d`.
- Dwa czyste buildy wygenerowały identyczny program i obraz ADF.
- Narzędzie ADF: `amitools 0.8.1`; test API 68000: `machine68k 0.3.0` i `vamos`.
- Headless: poprawny hunk LoadSeg i komunikat `PHOBOS A500 STAGE0 OK`.
- Emulator chipsetu: FS-UAE 3.2.35; repozytorium nie dostarcza chronionego Kickstart ROM.
- Test FS-UAE: Kickstart 1.3 rev 34.5, program PHOBOS widoczny, poprawny powrót do AmigaDOS.
- Test prawdziwej A500: odłożony przez użytkownika; Etap 01 pozostaje zablokowany.
- Chroniona baza `project/`: `52f14fee42de99063214f69f1acee2fba8f0e89a`.

## Uruchomienie

```bash
make -C ports/amiga500 bootstrap
make -C ports/amiga500 verify
KICKSTART_ROM=/sciezka/do/kick13.rom make -C ports/amiga500 emulator
```

Po wyświetleniu okna `PHOBOS - AMIGA 500` należy nacisnąć dowolny klawisz. Ten sam ADF
z `ports/amiga500/build/PHOBOS-A500.adf` jest artefaktem do testu na prawdziwym sprzęcie.
