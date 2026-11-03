# Amiga 500 — grafika, audio i zasoby

## Warunek rozpoczęcia

PoC techniczny Amigi jest zaakceptowany, a jego budżety są zamknięte.

## Cel

Zbudować kompletną, czytelną oprawę OCS bez przekroczenia Chip RAM, czasu blittera
i pojemności ADF.

## Status

`IMPLEMENTED` — oprawa i audio są w buildzie. Końcowa ocena na CRT i prawdziwej A500
pozostaje częścią Etapu 05.

## Grafika

- Wybrać rozdzielczość PAL i liczbę bitplanów na podstawie PoC.
- Zdefiniować wspólną paletę bio-industrial horror zgodną z ograniczeniami OCS.
- Przekonwertować gracza, trzy warianty skorpiona, leczenie i Overdrive.
- Przygotować kafle lub bitmapę areny, HUD, flash, tracer, trafienie i śmierć.
- Zredukować liczbę klatek animacji bez utraty rozpoznawalności.
- Przygotować bitmapowy font z literami `ĄĆĘŁŃÓŚŹŻ` i ich małymi odpowiednikami.

## Audio

- Odtworzyć strzał, trafienie, śmierć, pickup, ostrzeżenie fali i interfejs.
- Wybrać format muzyki i efektów odpowiedni dla czterech kanałów Paula.
- Zdefiniować priorytety kanałów, aby ważny sygnał nie był zagłuszany przez broń.
- Ustalić częstotliwości próbkowania i długości sampli w zatwierdzonym budżecie.
- Zapewnić wyciszenie bez zatrzymywania logiki gry.

## Pipeline zasobów

- Konwertery działają na macOS i zapisują do `ports/amiga500/assets/`.
- Każdy wynik ma manifest: źródło, checksumę, paletę, rozmiar i polecenie konwersji.
- Wygenerowane dane są deterministyczne i odtwarzalne z czystego checkoutu.
- Noty licencyjne użytych fontów i narzędzi trafiają do dystrybucji.

## Kryteria zakończenia

- [x] Gracz, przeciwnicy i pickupy mają osobne maski wygenerowane z zatwierdzonych źródeł.
- [x] Trzy warianty przeciwnika różnią się kolorem i obracają się w stronę gracza (16 kierunków).
- [x] Fonty Tektur i Oxanium zawierają `ĄĆĘŁŃÓŚŹŻ` i małe litery wymagane przez interfejs.
- [x] Wszystkie efekty dźwiękowe i cztery warstwy muzyki są syntezowane jak w `audio_lib.gd`.
- [x] Pipeline jest deterministyczny i nie zapisuje do `project/`.
- [x] Manifest zawiera ścieżki, checksumy i parametry wszystkich źródeł.
- [x] Licencje OFL fontów Tektur i Oxanium są dołączane do ADF.

## Implementacja

- `tools/convert_assets.py` — wspólna paleta OCS (16 kolorów areny, 16 sprite'ów, osobne
  palety HUD i menu), tło areny z `arena_floor.svg` przyciemnione jak oświetlenie w grze
  (z winietą i niebieskimi ścianami), skorpiony 3 × 16 kierunków × 4 klatki (boby 16×16
  z maską), fazy pojawiania się i obracający się telegraph, pickupy (8 klatek obrotu),
  eksplozje odwzorowujące `GPUParticles3D` (24 cząstki, 0,6 s), gracz 16 kierunków × 4
  klatki jako dwie pary sprite'ów attached (15 kolorów), celownik i błysk lufy, fonty
  Tektur 23/17 px i Oxanium 10 px, tablice sin/atan.
- Podgląd konwersji: `assets/generated/preview/*.png`.
- Kompresja na dyskietce: grafika LZSS, muzyka IMA ADPCM 4-bit (rozpakowywana etapami
  w menu), efekty 8-bit PCM 11 kHz bez strat.
- `src/audio.c` — Paula bezpośrednio: kanały 0+1 muzyka (strumień z przerwania AUD0,
  przejścia warstw 0,4 s jak `set_music_intensity`, ściszanie przy HP < 30%), kanał 2 broń,
  kanał 3 zdarzenia z priorytetami; losowa wysokość strzału i śmierci jak w oryginale.
