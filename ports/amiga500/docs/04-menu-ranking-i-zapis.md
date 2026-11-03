# Amiga 500 — menu, ranking i zapis

## Warunek rozpoczęcia

Pełna pętla gry Amigi jest zaakceptowana.

## Cel

Dodać kompletny interfejs oraz trwały ranking bez ryzyka uszkodzenia obrazu ADF.

## Status

`IMPLEMENTED` — menu, trudności, inicjały, Top 10 i format zapisu są w finalnym ADF.
Test trwałości na fizycznym, zapisywalnym nośniku pozostaje częścią Etapu 05.

## Zakres

- Menu: `GRAJ`, `TRUDNOŚĆ`, `WYNIKI`, `WYJŚCIE` lub równoważny powrót do Workbench.
- Wybór i zapamiętanie trudności.
- Wpisywanie trzech inicjałów w obu trybach sterowania.
- Top 10 osobno dla Łatwego, Normalnego i Trudnego.
- Rekord: inicjały, wynik, fala, zabójstwa i czas; data jest opcjonalna bez zegara RTC.
- Zapis do osobnego pliku na zapisywalnym ADF lub zatwierdzonego dysku wyników.
- Jasny komunikat dla nośnika zabezpieczonego przed zapisem albo błędu I/O.

## Bezpieczeństwo danych

- Gra nie nadpisuje pliku wykonywalnego ani zasobów.
- Nowy ranking jest walidowany przed zastąpieniem poprzedniego.
- Przerwany zapis nie może uniemożliwić ponownego uruchomienia gry.
- Uszkodzone dane są ignorowane i zastępowane pustym rankingiem po potwierdzeniu użytkownika.

## Kryteria zakończenia

- [x] Wszystkie ekrany obsługują mysz + klawiaturę oraz joystick + klawiaturę.
- [x] Ranking poprawnie sortuje, ogranicza i filtruje wyniki.
- [ ] Wyniki pozostają po zimnym restarcie prawdziwej Amigi.
- [x] Brak zapisu i write-protect nie zawieszają gry; błąd jest sygnalizowany w menu.
- [x] Wpisywanie inicjałów obsługuje litery A–Z, klawisze kierunkowe i potwierdzenie strzałem.
- [x] Interfejs mieści się w obszarze 320×256 PAL.
- [x] Drzewo `project/` nie zostało zmienione.

## Format i bezpieczeństwo

- `PHOBOS.SCORES` zawiera wersję, wybraną trudność, ostatnie inicjały i trzy tablice Top 10.
- Każdy zapis ma checksumę FNV-1a i jest walidowany przed użyciem.
- Nowe dane trafiają najpierw do `PHOBOS.NEW`.
- Poprzedni ranking jest zachowany jako `PHOBOS.BAK`; po błędzie odczyt używa kopii.
- Ranking jest opcjonalny: write-protect nie blokuje menu ani rozpoczęcia kolejnej rundy.
- Rekord przechowuje inicjały, wynik, falę, zabójstwa i czas; data została pominięta z powodu braku RTC.
