# Raport testów wydania iOS (szablon)

Wypełnia użytkownik na buildzie z TestFlight. Kopiuj ten plik na każde wydanie albo nadpisuj
go i commituj razem z tagiem wydania.

## Build

| Pole | Wartość |
|---|---|
| Wersja (build) | 0.1.0 (…) |
| Data testów | 2026-…-… |
| Źródło | TestFlight |
| Rozmiar `.ipa` (cel < 100 MB) | … MB |

## Urządzenia

| Urządzenie | iOS / iPadOS | Proporcje | Uwagi |
|---|---|---|---|
| iPhone … | … | 19.5:9 | |
| iPad … | … | 4.3:3 | |
| Kontroler (np. DualSense) | — | — | |

## Testy funkcjonalne

Sterowanie, safe area, ikona i symbole przeszły w etapach 01–03 (2026-11-04). Zapis rankingu
sprawdzamy ponownie, bo build z TestFlight to nowa instalacja. Tutaj szybki
przegląd buildu z TestFlight:

| Test | iPhone | iPad |
|---|---|---|
| Zimny start → menu → wybór trudności → pełna runda | ☐ | ☐ |
| Ekran LICENCJE: otwiera się, przewija płynnie ▲▼, WSTECZ wraca | ☐ | ☐ |
| Pauza (II), wyciszenie (♪), wpisanie inicjałów | ☐ | ☐ |
| Przerwania: połączenie przychodzące i przejście do tła → gra pauzuje się; Centrum sterowania → zanotuj, czy gra się zatrzymuje (pauza obsługiwana tylko przy przejściu do tła) | ☐ | ☐ |
| Ranking po zabiciu aplikacji i ponownym uruchomieniu | ☐ | ☐ |
| Ranking po aktualizacji przez TestFlight (nowy build) | ☐ | ☐ |
| Kontroler: przełączanie dotyk ↔ pad w trakcie rundy | ☐ | ☐ |

## Wydajność

| Pomiar | Limit | Wynik |
|---|---|---|
| FPS przy 45 aktywnych wrogach (licznik FPS w prawym górnym rogu) | stabilne 60 FPS | |
| Czas od dotknięcia ikony do menu (z generowaniem dźwięku) | ≤ 3 s | |
| Po 15 min gry: temperatura, bateria, spadki FPS | bez spadków poniżej 60 FPS | |

Przekroczenie limitu: wpisz wynik i urządzenie; poprawka (np. generowanie dźwięku w tle) idzie
osobnym zadaniem.

## Regresja macOS

| Test | Wynik |
|---|---|
| `./build.sh macos` przechodzi | ☐ |
| Gra na macOS: DualSense, klawiatura i mysz bez zmian | ☐ |

## Decyzja

| Pole | Wartość |
|---|---|
| Wynik | OK / do poprawy |
| Uwagi | |
| Wysłano do App Review | data |
| Status wydania | — |
