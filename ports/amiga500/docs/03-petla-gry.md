# Amiga 500 — pętla gry

## Warunek rozpoczęcia

Oprawa i pipeline zasobów Amigi są zaakceptowane.

## Cel

Odtworzyć pełną rundę PHOBOS w limitach ustalonych przez PoC.

## Status

`IMPLEMENTED` — pełna pętla i testy deterministyczne przechodzą. Długie sesje na prawdziwej
A500 pozostają częścią Etapu 05.

## Zakres

- Director fal: telegraph, spawn z krawędzi, przerwa i narastająca presja.
- Czerwony, bursztynowy i fioletowy skorpion z rozkładem oraz punktacją portu.
- Zdrowie, obrażenia kontaktowe i czas niewrażliwości.
- Leczenie, Overdrive, czas życia pickupów i mechanizm litości.
- Trzy trudności wpływające wyłącznie na częstotliwość dropów.
- Punkty, zabójstwa, fala, czas rundy, game over i szybki restart.
- Pauza, wyciszenie i obsługa odłączenia lub zmiany urządzenia wejściowego.

## Balans portu

Wartości macOS są punktem startowym. Zmiana limitu przeciwników, długości fal lub tempa
spawnu musi utrzymywać podobną krzywą presji i zostać zapisana w macierzy zgodności.
Rozkład wariantów i relacja punktów `10 / 25 / 50` pozostają niezmienione, chyba że test
wykaże techniczną konieczność odstępstwa.

## Testy

- Deterministyczny test przejść stanów rundy.
- Test granic puli i braku spawnu bezpośrednio obok gracza.
- Test rozkładu wariantów i dropów na dużej próbce poza pętlą czasu rzeczywistego.
- Test Overdrive, pity dropu, punktacji i czasu niewrażliwości.
- Stress test z maksymalnym zatwierdzonym limitem obiektów.

## Kryteria zakończenia

- [x] Pełna runda od startu do game over nie wymaga restartu programu.
- [x] Director używa fal 35–65 s, przerw, telegraphu i stopniowego wzrostu presji.
- [x] Wszystkie trzy warianty, oba pickupy i trzy profile trudności działają poprawnie.
- [x] Punktacja, zabójstwa, fala, czas Overdrive i dane końca rundy są kompletne.
- [x] Statyczne pule ograniczają grę do 16 przeciwników i 8 pickupów.
- [x] Test 10 000 wariantów potwierdza rozkład 70/22/8 z tolerancją statystyczną.
- [x] Test headless przechodzi co najmniej trzy fale bez przekroczenia pul.
- [x] Drzewo `project/` nie zostało zmienione.

## Adaptacje Amigi

| Element | macOS | Amiga 500 | Status | Powód |
|---|---:|---:|---|---|
| Arena i kamera | 40×24 j., widok z góry | 8 px/j., 320×200, ściany widoczne | ZGODNE | — |
| Ruch gracza | 11 j/s, accel 12 | 11 j/s, accel 12 (Q10) | ZGODNE | — |
| Celowanie | mysz / prawa gałka | mysz z celownikiem / kursory | DOSTOSOWANE | brak drugiej gałki; kursory strzelają ciągle |
| Częstotliwość ognia | 9/s (8,6/s przy 60 Hz) | 8,3/s; Overdrive 12,5/s | ZGODNE | podział 50 Hz |
| Logika i obraz | 60 Hz | logika 50 Hz, obraz 25 kl./s | DOSTOSOWANE | budżet blittera OCS |
| Director fal | 35–65 s, cel 8+3/falę, grupy, dobór | identyczny | ZGODNE | — |
| Maks. przeciwników | 60 w puli, cel do 45 | 30 w puli, cel do 30 | DOSTOSOWANE | przepustowość szyny Chip |
| Warianty i punkty | 70/22/8; 10/25/50 | bez zmian | ZGODNE | — |
| Dropy i litość | profile trudności | identyczne | ZGODNE | — |
| Efekty | tracer, błysk, eksplozje, wstrząs, winieta, Overdrive | wszystkie, przez boby, sprite'y i palety Coppera | DOSTOSOWANE | brak shaderów |
| Oświetlenie | światła punktowe w narożnikach | pominięte | DOSTOSOWANE | 16 kolorów areny |

Przy 8–16 przeciwnikach obraz utrzymuje 25 kl./s; przy 20–30 spada do ok. 15–20 kl./s,
a logika nadal liczy 50 kroków na sekundę, więc tempo gry się nie zmienia.
