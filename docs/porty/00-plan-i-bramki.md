# Porty retro — plan i bramki

## Cel

Przenieść PHOBOS kolejno na Amigę 500 i Commodore 64 bez naruszania istniejącej
wersji Godot dla macOS. Porty są osobnymi implementacjami opartymi na kontrakcie
rozgrywki, a nie próbą uruchomienia projektu Godot na sprzęcie retro.

## Kolejność

1. Amiga 500: implementacja, testy na emulatorze i prawdziwym sprzęcie, akceptacja użytkownika.
2. Commodore 64: rozpoczęcie dopiero po nadaniu portowi Amigi statusu `APPROVED`.

| Platforma | Status początkowy | Warunek rozpoczęcia | Artefakt końcowy |
|---|---|---|---|
| Amiga 500 | `PLANNED` | Akceptacja pierwszego etapu | Bootowalny i zapisywalny obraz ADF |
| Commodore 64 | `BLOCKED` | Status `APPROVED` Amigi 500 | Bootowalny i zapisywalny obraz D64 |

Status Amigi jest nadawany wyłącznie przez użytkownika w
`ports/amiga500/docs/05-build-testy-i-akceptacja.md`. Samo przejście testów nie
odblokowuje C64.

## Port iOS / iPadOS (osobna ścieżka)

Port na iPhone i iPad nie jest portem retro i nie zależy od kolejności Amiga → C64.
Plan, analiza licencji, wybór silnika (Godot vs Unity) i ocena PS5 są w
`ports/ios/docs/00-zalozenia-licencje-i-platformy.md`.

| Platforma | Status początkowy | Warunek rozpoczęcia | Artefakt końcowy |
|---|---|---|---|
| iOS / iPadOS | `IN_PROGRESS` (etap 00 `APPROVED`) | Akceptacja kolejnych etapów portu iOS | Build `.ipa` zaakceptowany w App Store |

Port iOS podlega tej samej izolacji co porty retro: to osobny projekt Godot w
`ports/ios/project/` (kopia `project/` z commitu zapisanego w `ports/ios/BASELINE`).
Port nie modyfikuje `project/` (decyzja użytkownika z 2026-11-03).

## Izolacja platform

- `project/` pozostaje jedynym źródłem wersji Godot/macOS i nie jest modyfikowany przez porty.
- Każdy port ma własne `src/`, `assets/`, `tools/`, `tests/`, `build/` i `docs/`.
- Narzędzia portów mogą czytać zasoby z `project/assets/`, ale zapisują wyłącznie do katalogu danego portu.
- Kod wykonywalny, biblioteki i przetworzone zasoby nie są współdzielone między targetami.
- Wspólne są tylko dokumenty kontraktu i jawnie przepisane reguły rozgrywki.
- Katalogi `build/` i pliki tymczasowe portów nie będą wersjonowane.
- Każdy etap kończy się sprawdzeniem, że drzewo `project/` nie zostało zmienione.

Docelowa struktura:

```text
docs/porty/
├── 00-plan-i-bramki.md
└── 01-kontrakt-zgodnosci.md
ports/
├── amiga500/
│   ├── docs/
│   ├── src/
│   ├── assets/
│   ├── tools/
│   ├── tests/
│   └── build/
└── commodore64/
    ├── docs/
    ├── src/
    ├── assets/
    ├── tools/
    ├── tests/
    └── build/
```

## Zasada realizacji

- Każdy etap wymaga osobnej akceptacji użytkownika przed rozpoczęciem implementacji.
- Nie rozpoczynamy następnego etapu na podstawie samej akceptacji całego planu.
- Niezaakceptowany prototyp jest poprawiany w obrębie bieżącego etapu.
- Odstępstwo od kontraktu rozgrywki wymaga wpisu w macierzy zgodności i akceptacji użytkownika.
- Test na prawdziwym sprzęcie jest obowiązkową częścią wydania obu portów.

## Kontrola wersji macOS

Przed rozpoczęciem portu zapisujemy identyfikator drzewa `project/` jako punkt odniesienia.
Po każdym etapie porównujemy go z bieżącym drzewem i uruchamiamy końcowy build macOS.
Zmiany naprawcze wersji macOS są prowadzone osobno i nie mogą być ukryte w commitach portu.

## Warunki zatrzymania

Prace zatrzymujemy i wracamy do planowania, gdy:

- wymagany budżet pamięci lub czasu klatki nie mieści się na sprzęcie docelowym,
- wybrany sposób sterowania nie jest grywalny na prawdziwym sprzęcie,
- zapis na nośniku grozi uszkodzeniem obrazu lub danych użytkownika,
- zachowanie kluczowej mechaniki wymaga niezaakceptowanego odstępstwa,
- narzędzia portu zapisują cokolwiek w `project/`.
