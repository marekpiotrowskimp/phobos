# Commodore 64 — grafika, audio i zasoby

## Warunek rozpoczęcia

PoC techniczny C64 jest zaakceptowany, a mapa pamięci i model renderowania są zamknięte.

## Cel

Zbudować kompletną i czytelną oprawę VIC-II/SID mieszczącą się w 64 KB oraz na D64.

## Grafika

- Przygotować arenę dla trybu wybranego w PoC.
- Zdefiniować paletę wykorzystującą stałe kolory VIC-II.
- Przekonwertować gracza, trzy warianty skorpiona, leczenie i Overdrive.
- Przygotować HUD, flash, tracer, trafienie i śmierć.
- Opracować własny charset z polskimi znakami i symbolami interfejsu.
- Zaplanować reuse danych sprite'ów i animacji bez kopiowania zbędnych klatek.

## Audio

- Odtworzyć strzał, trafienie, śmierć, pickup, ostrzeżenie i interfejs za pomocą SID.
- Przygotować muzykę mieszczącą się w budżecie pamięci i czasu CPU.
- Zdefiniować priorytety trzech głosów SID między muzyką i krytycznymi efektami.
- Zapewnić wyciszenie oraz poprawny reset rejestrów SID po zakończeniu gry.

## Pipeline zasobów

- Konwertery działają na macOS i zapisują do `ports/commodore64/assets/`.
- Każdy plik wynikowy ma manifest źródła, checksumy, palety i parametrów konwersji.
- Build wykrywa przekroczenie mapy pamięci i rozmiaru D64.
- Dane są deterministyczne i odtwarzalne z czystego checkoutu.
- Noty licencyjne trafiają do dystrybucji w formie mieszczącej się na nośniku lub obok obrazu.

## Kryteria zakończenia

- [ ] Gracz, trzy warianty przeciwników i pickupy są jednoznacznie rozpoznawalne.
- [ ] Rozróżnienie wariantów nie opiera się wyłącznie na kolorze.
- [ ] Polskie komunikaty wykorzystują poprawne glify własnego charsetu.
- [ ] Raster i multiplekser pozostają stabilne podczas efektów oraz HUD.
- [ ] SID zachowuje krytyczne sygnały przy aktywnej muzyce.
- [ ] Zasoby mieszczą się w mapie pamięci, czasie CPU i na D64.
- [ ] Pipeline nie zapisuje do `project/` ani `ports/amiga500/`.
