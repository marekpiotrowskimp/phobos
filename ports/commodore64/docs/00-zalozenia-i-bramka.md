# Commodore 64 — założenia i bramka

## Status

`BLOCKED`

Nie wolno rozpoczynać implementacji, PoC, konwersji zasobów ani konfiguracji toolchainu C64,
dopóki użytkownik nie zaznaczy decyzji `APPROVED` w
`ports/amiga500/docs/05-build-testy-i-akceptacja.md`.

## Warunek odblokowania

- [ ] Port Amigi 500 ma decyzję użytkownika `APPROVED`.
- [ ] Wpis zawiera datę oraz wersję lub checksumę zatwierdzonego ADF.
- [ ] Użytkownik osobno zaakceptował rozpoczęcie Etapu 00 C64.

Spełnienie tych warunków zmienia status na `PLANNED`, nie uruchamia automatycznie następnych etapów.

## Target

- Commodore 64 PAL z 64 KB RAM i standardowymi układami VIC-II, SID oraz CIA.
- Brak wymagania REU, rozszerzenia RAM, akceleratora lub kartridża.
- Standardowa klawiatura, joystick oraz mysz zgodna z Commodore 1351.
- Dystrybucja jako bootowalny obraz D64.
- Walidacja w VICE oraz na prawdziwym Commodore 64 PAL.

## Zakres etapu po odblokowaniu

1. Przygotować toolchain `cc65/ca65` albo zaakceptowany odpowiednik działający na macOS.
2. Zbudować minimalny PRG oraz bootowalny D64.
3. Zweryfikować start w VICE i na prawdziwym C64.
4. Zdefiniować mapę pamięci dla kodu, stosu, ekranu, charsetu, sprite'ów, audio i stanu gry.
5. Ustalić zasady użycia kodu C i asemblera w ścieżkach krytycznych.
6. Zapisać identyfikator drzewa `project/` i zatwierdzonego portu Amigi.

## Wymagania architektury

- Kod C64 jest niezależny od kodu Amigi i Godot.
- Główna pętla nie korzysta z dynamicznej alokacji pamięci.
- Pozycje i prędkości używają liczb całkowitych lub stałoprzecinkowych.
- Raster IRQ, wejście, SID i zapis mają osobne, jawne granice odpowiedzialności.
- Narzędzia zapisują wyłącznie do `ports/commodore64/`.
- Każda decyzja redukująca mechanikę trafia do macierzy zgodności.

## Budżety do zatwierdzenia

| Obszar | Pomiar PoC | Limit końcowy |
|---|---:|---:|
| Kod i dane stałe | — | Do ustalenia |
| Ekran, charset i sprite'y | — | Do ustalenia |
| Stan gry i pule obiektów | — | Do ustalenia |
| Czas CPU w ramce PAL | — | Do ustalenia |
| Aktywni przeciwnicy | — | Do ustalenia |
| Rozmiar D64 | — | ≤ 174 848 bajtów |

## Kryteria zakończenia

- [ ] Wszystkie warunki odblokowania zostały spełnione.
- [ ] Toolchain buduje minimalny projekt na macOS.
- [ ] D64 startuje w czystej konfiguracji PAL C64 w VICE.
- [ ] Ten sam D64 startuje na prawdziwym C64 PAL.
- [ ] Powstała mapa pamięci i tabela budżetów z marginesem bezpieczeństwa.
- [ ] Licencje toolchainu pozwalają na planowaną dystrybucję.
- [ ] Drzewa `project/` i `ports/amiga500/` nie zostały zmienione.
