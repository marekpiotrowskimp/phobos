# Amiga 500 — build, testy i akceptacja

## Warunek rozpoczęcia

Menu, ranking i zapis Amigi są zaakceptowane.

## Cel

Przygotować odtwarzalny obraz ADF, zakończyć walidację na prawdziwym sprzęcie i uzyskać
formalną decyzję użytkownika. Dopiero status `APPROVED` odblokowuje prace nad C64.

## Artefakty wydania

- Bootowalny obraz ADF mieszczący grę, zasoby i wymagane noty.
- Plik checksumy obrazu.
- Raport toolchainu, konfiguracji sprzętu i wyników testów.
- Macierz zgodności wobec wersji macOS.
- Instrukcja sterowania dla obu trybów.

## Test emulatora

- Czysta konfiguracja PAL A500, OCS, 512 KB Chip + 512 KB expansion.
- Zimny boot z ADF bez dysku twardego.
- Trzy pełne rundy, oba tryby sterowania, pauza, wyciszenie i restart.
- Zapis rankingu, restart emulatora i ponowny odczyt.
- Stress test maksymalnej zatwierdzonej liczby obiektów.

## Budżet wydajności

- PAL A500 OCS, 68000 7,09 MHz, Kickstart 1.3, 512 KB Chip + 512 KB expansion.
- Arena: 4 bitplany przeplatane, dwa bufory 336×216 (margines na wstrząs), statyczne tło
  w Chip RAM; odtwarzane są tylko prostokąty poprzednich obiektów.
- Przeciwnicy, pickupy, telegraphy i eksplozje to boby; gracz, celownik i błysk lufy to
  sprite'y sprzętowe; HUD to osobne bitmapy podpinane Copperem i aktualizowane tylko po zmianie.
- Obraz w grze jest stały 25 kl./s; logika liczy kroki 50 Hz według licznika VBlank.
- Pomiar w FS-UAE (`make demo`, A500 cycle-exact): 25 kl./s do ok. 16 przeciwników,
  ok. 20 kl./s przy 17–20, ok. 13–15 kl./s przy 23. Wolna pamięć Chip po starcie: ok. 96 KB.
- Rozmiar programu: ok. 250 KB (grafika LZSS, muzyka ADPCM).

## Narzędzia diagnostyczne

- `make demo` uruchamia `PHOBOS --demo` w FS-UAE z portem szeregowym zapisywanym do pliku.
  Program sam gra (jak `--autotest` w Godot), co sekundę wysyła pomiary (FPS, linie rastra
  na fazy renderu i logiki, liczba przeciwników) i zrzuty pamięci ekranu.
- `tools/render_dump.py` odtwarza z prawdziwej listy Coppera, bitplanów i sprite'ów obrazy
  PNG w `build/demo/` (menu, gra, pauza, inicjały, wyniki).

## Test prawdziwego sprzętu

- Prawdziwa Amiga 500 PAL z 1 MB RAM bez akceleratora.
- Uruchomienie obrazu z fizycznego nośnika lub emulatora stacji zgodnego z A500.
- Monitor CRT lub typowy adapter obrazu używany przez właściciela sprzętu.
- Co najmniej trzy pełne rundy bez zawieszenia i utraty wejścia.
- Zapis i odczyt rankingu po wyłączeniu oraz ponownym uruchomieniu komputera.

## Regresja macOS

- Drzewo `project/` jest zgodne z zapisaną bazą albo różnice mają osobny, zatwierdzony commit.
- Końcowy build macOS uruchamia się i przechodzi istniejący autotest oraz stress test.
- Narzędzia Amigi nie pozostawiają plików w `project/`.

## Kryteria techniczne

- [ ] ADF przechodzi trzy pełne rundy oraz stress test emulatora bez wartości `DROP`.
- [ ] Ten sam ADF przechodzi wszystkie testy prawdziwej A500 1 MB.
- [ ] Oba tryby sterowania są kompletne i grywalne.
- [ ] Ranking zachowuje dane po zimnym restarcie.
- [ ] Nie pozostały otwarte obowiązkowe pozycje macierzy zgodności.
- [ ] Build jest odtwarzalny z czystego checkoutu.
- [ ] Wersja macOS przechodzi test regresji i nie została naruszona.

## Decyzja użytkownika

- [ ] `APPROVED` — port Amigi 500 jest gotowy; można rozpocząć Etap 00 C64.
- [ ] `ITERATE` — port wraca do wskazanego etapu Amigi; C64 pozostaje zablokowany.
- [ ] `STOP` — port Amigi zostaje zatrzymany; C64 pozostaje zablokowany.

Data decyzji: —

Wersja/checksum ADF: `17525f3ebb3725ea31924bbffcc4d006581b8c84a4e615b5eb8e7c687c23c1a9`

Uwagi: —
