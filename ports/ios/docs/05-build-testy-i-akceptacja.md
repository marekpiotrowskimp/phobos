# iOS / iPadOS — build, testy i akceptacja

## Warunek rozpoczęcia

Etap 04 ma status `APPROVED`.

## Cel

Wydać grę przez TestFlight, potwierdzić jakość na fizycznych urządzeniach i zgłosić ją
do App Review. Wersję do sklepu zatwierdza wyłącznie użytkownik.

## Artefakty wydania

- `PHOBOS.ipa` zbudowany przez `./build.sh ios` z czystego klonu.
- Numer wersji i buildu zgodny z wersją macOS.
- Raport testów: urządzenia, wersje iOS, FPS, wyniki rund.
- Zaktualizowana macierz zgodności wobec wersji macOS.

## Testy funkcjonalne

- Zimny start, menu, wybór trudności, trzy pełne rundy na każdej klasie urządzeń z etapu 03.
- Dotyk i pad: przełączanie w trakcie gry, odłączenie pada podczas rundy (gra się pauzuje).
- Pauza, wyciszenie, restart i wpisanie inicjałów.
- Przerwania: połączenie przychodzące, Centrum sterowania, przejście do tła i powrót.
- Ranking: zapis, zabicie aplikacji, ponowne uruchomienie, aktualizacja przez TestFlight.

## Testy wydajności

| Pomiar | Limit |
|---|---|
| FPS przy 45 aktywnych wrogach (najstarsze wspierane urządzenie) | stabilne 60 |
| Czas od uruchomienia do menu, w tym generowanie audio w `audio_lib.gd` | ≤ 3 s |
| Temperatura i bateria po 15 min gry | bez throttlingu skutkującego spadkiem poniżej 60 FPS |
| Rozmiar `.ipa` | do zmierzenia; cel < 100 MB |

Generowanie SFX i muzyki przy starcie może trwać zauważalnie dłużej na telefonie.
Jeśli przekroczy limit, trzeba przenieść je do wątku w tle albo wypiec do zasobów.
Zmiana dotyczy tylko projektu iOS.

## Regresja macOS

- `./build.sh macos` przechodzi.
- Ręczny test DualSense, klawiatury i myszy na macOS.
- Drzewo `project/` równe `PROJECT_TREE_BASELINE`; port iOS nie zmienił wersji macOS.
- `diff_from_macos.sh`: wszystkie zmiany macOS od `BASELINE` przeniesione albo opisane
  w macierzy zgodności.

## TestFlight i App Review

1. Wysłanie buildu do App Store Connect i przejście przetwarzania.
2. Testy wewnętrzne w TestFlight na urządzeniach użytkownika.
3. Opcjonalnie testerzy zewnętrzni (wymaga skróconej recenzji Apple).
4. Zgłoszenie do App Review i reakcja na ewentualne odrzucenie według tabeli ryzyk z etapu 04.

## Decyzja użytkownika

| Pole | Wartość |
|---|---|
| Status | `PLANNED` |
| Data | — |
| Wersja / build | — |
| Uwagi | — |

Status `APPROVED` nadaje wyłącznie użytkownik. Dopiero wtedy build trafia do sprzedaży.
