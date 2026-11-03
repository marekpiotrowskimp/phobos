# iOS / iPadOS — UI, safe area i proporcje

## Warunek rozpoczęcia

Etap 02 ma status `APPROVED`.

## Cel

Arena ma być widoczna w całości (wymóg kontraktu zgodności), a HUD czytelny na każdym
wspieranym urządzeniu. Elementy interfejsu nie mogą trafiać pod notch, Dynamic Island
ani pasek Home.

## Obecny stan

- Viewport 1280×720 (16:9), `stretch/mode="canvas_items"`, `stretch/aspect="keep"`.
- Na iPhonie (ok. 19.5:9) `keep` daje pionowe czarne pasy po bokach, a na iPadzie
  (4:3, 4.3:3) poziome pasy u góry i u dołu.

## Zakres

1. Zmienić `stretch/aspect` na `expand`: arena pozostaje wyśrodkowana i w całości widoczna,
   a dodatkowa przestrzeń pokazuje tło lub otoczenie areny zamiast czarnych pasów.
   Kamera zachowuje obecny kadr areny.
2. Zakotwiczyć HUD (`hud.gd`) do krawędzi ekranu z marginesami z
   `DisplayServer.get_display_safe_area()`.
3. Umieścić przyciski pauzy i drążki w obrębie safe area.
4. Skalowanie tekstu: minimalna wysokość fontu na iPhonie z najmniejszym ekranem.
   Sprawdzić czytelność fontów Oxanium i Tektur.
5. Zapis rankingu `user://phobos.cfg` trafia na iOS do katalogu danych aplikacji, bez zmian
   w kodzie. Sprawdzić odczyt po zamknięciu i ponownym uruchomieniu oraz po aktualizacji
   aplikacji przez TestFlight.
6. Cykl życia: pauza i zapis przy przejściu do tła (`NOTIFICATION_APPLICATION_PAUSED`),
   wyciszenie audio przy przełączniku wyciszenia telefonu, zgodnie z kategorią sesji audio
   „ambient”.

## Macierz urządzeń testowych

| Klasa | Przykład | Proporcje | Uwagi |
|---|---|---|---|
| Mały iPhone | iPhone SE / 13 mini | 16:9 / 19.5:9 | najmniejszy tekst |
| Typowy iPhone | iPhone z Dynamic Island | 19.5:9 | safe area poziomo |
| iPad | iPad 10. gen / mini | 4.3:3 | drążki przy dużej przekątnej |
| iPad Pro | 13" | 4.3:3 | ProMotion 120 Hz, logika 60 Hz fizyki |

## Bramka akceptacji

- Zrzuty ekranu menu, rozgrywki, pauzy, końca rundy i rankingu na każdej klasie urządzeń.
- Arena w całości widoczna, żaden element nie leży pod notchem ani paskiem Home.
- Ranking przetrwał restart i aktualizację aplikacji.
- Drzewo `project/` (macOS) jest niezmienione.
- Akceptacja użytkownika.
