# Commodore 64 — build, testy i akceptacja

## Warunek rozpoczęcia

Menu, ranking i zapis C64 są zaakceptowane.

## Cel

Przygotować odtwarzalny obraz D64 i zakończyć walidację portu na emulatorze oraz
prawdziwym Commodore 64 PAL.

## Artefakty wydania

- Bootowalny obraz D64 z grą, zasobami i rankingiem.
- Plik checksumy obrazu.
- Raport toolchainu, modelu VIC-II/SID, napędu i wyników testów.
- Końcowa macierz zgodności C64 wobec Amigi i macOS.
- Instrukcja myszy 1351 + klawiatury oraz joysticka + klawiatury.

## Test VICE

- Czysta konfiguracja PAL C64 bez rozszerzeń.
- Zimny boot z D64 w emulowanym napędzie 1541.
- Trzy pełne rundy, oba tryby sterowania, pauza, wyciszenie i restart.
- Zapis rankingu, restart emulatora i ponowny odczyt.
- Stress test maksymalnej zatwierdzonej liczby obiektów.

## Test prawdziwego sprzętu

- Prawdziwy Commodore 64 PAL z 64 KB, bez REU i akceleratora.
- Napęd 1541 lub sprzęt zgodny czasowo i funkcjonalnie z zatwierdzonym sposobem dystrybucji.
- Mysz Commodore 1351 lub w pełni zgodny zamiennik oraz standardowy joystick.
- Co najmniej trzy pełne rundy bez zawieszenia, błędów rastra i utraty wejścia.
- Zapis oraz odczyt rankingu po wyłączeniu komputera i napędu.

## Regresja pozostałych platform

- Drzewa `project/` i `ports/amiga500/` są zgodne z zapisanymi bazami.
- Końcowy build macOS przechodzi istniejące testy.
- Zatwierdzony ADF Amigi zachowuje checksumę i uruchamia się bez zmian.
- Narzędzia C64 nie pozostawiają plików w katalogach innych platform.

## Kryteria techniczne

- [ ] D64 przechodzi wszystkie testy VICE.
- [ ] Ten sam D64 przechodzi wszystkie testy prawdziwego C64 PAL.
- [ ] Oba tryby sterowania są kompletne i grywalne.
- [ ] Ranking zachowuje dane po zimnym restarcie.
- [ ] Nie pozostały otwarte obowiązkowe pozycje macierzy zgodności.
- [ ] Build jest odtwarzalny z czystego checkoutu.
- [ ] Wersje Amigi i macOS nie zostały naruszone.

## Decyzja użytkownika

- [ ] `APPROVED` — port C64 jest gotowy.
- [ ] `ITERATE` — port wraca do wskazanego etapu C64.
- [ ] `STOP` — prace nad portem C64 zostają zatrzymane.

Data decyzji: —

Wersja/checksum D64: —

Uwagi: —
