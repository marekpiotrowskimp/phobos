# Commodore 64 — menu, ranking i zapis

## Warunek rozpoczęcia

Pełna pętla gry C64 jest zaakceptowana.

## Cel

Dodać kompletny interfejs i trwały ranking zapisujący się bezpiecznie na D64.

## Zakres

- Menu: `GRAJ`, `TRUDNOŚĆ`, `WYNIKI`, `WYJŚCIE` lub powrót do BASIC.
- Wybór oraz zapamiętanie trudności.
- Wpisywanie trzech inicjałów w obu trybach sterowania.
- Top 10 osobno dla każdej trudności.
- Rekord: inicjały, wynik, fala, zabójstwa i czas; data jest opcjonalna.
- Zapis rankingu jako osobny plik na zapisywalnym D64.
- Obsługa write-protect, braku dysku, błędu napędu i przerwanego zapisu.

## Bezpieczeństwo danych

- Zapis nie modyfikuje programu ani plików zasobów.
- Nowe dane zawierają wersję formatu i sumę kontrolną.
- Poprzedni ranking pozostaje dostępny do czasu zakończenia poprawnego zapisu.
- Błąd napędu nie pozostawia gry w nieskończonym oczekiwaniu.
- Uszkodzony ranking można zresetować bez ponownego tworzenia D64.

## Kryteria zakończenia

- [ ] Menu i inicjały działają myszą 1351 + klawiaturą oraz joystickiem + klawiaturą.
- [ ] Ranking poprawnie sortuje, ogranicza i filtruje wyniki.
- [ ] Wyniki pozostają po zimnym restarcie prawdziwego C64 i napędu.
- [ ] Write-protect, brak dysku i błąd napędu mają czytelny limit czasu oraz komunikat.
- [ ] Przerwany zapis nie uniemożliwia bootowania gry.
- [ ] Interfejs mieści się w bezpiecznym obszarze PAL/CRT.
- [ ] Drzewa pozostałych platform nie zostały zmienione.
