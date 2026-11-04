# iOS / iPadOS — build, testy i akceptacja

## Warunek rozpoczęcia

Etap 04 ma status `APPROVED`.

## Cel

Przygotować build wydania i komplet materiałów, z którymi użytkownik sam przeprowadzi
TestFlight, App Review i publikację. Wersję do sklepu zatwierdza i publikuje wyłącznie
użytkownik.

## Podział pracy

| Kto | Co |
|---|---|
| **Agent** | numer wersji i buildu, `./build.sh ios` dający archiwum gotowe do wysyłki, automatyczne testy wydania, pomiar startu i rozmiaru, instrukcja wysyłki, szablon raportu testów, notatki dla App Review, tekst „Co nowego” |
| **Użytkownik** | wysyłka buildu do App Store Connect, testy w TestFlight, zgłoszenie do App Review, odpowiedź na ewentualne odrzucenie, publikacja wydania |

## Materiały od agenta (`ports/ios/release/`)

| Plik | Zawartość |
|---|---|
| `release-guide.md` | krok po kroku: build, wysyłka (Xcode Organizer albo Transporter), TestFlight wewnętrzny, zgłoszenie do recenzji, ręczne albo automatyczne wydanie |
| `test-report.md` | szablon raportu: urządzenia, wersje iOS, FPS, rundy, wynik listy testów poniżej |
| `review-notes.md` | notatki dla recenzenta (PL/EN): jak grać dotykiem, że pad jest opcjonalny, brak kont i danych do logowania |
| `release-checklist.md` | lista przed kliknięciem „Submit for Review”: wersja, build, metadane z etapu 04, zrzuty, polityka prywatności, klasyfikacja wiekowa |

## Artefakty wydania

- Archiwum lub `PHOBOS.ipa` zbudowane przez `./build.sh ios` z czystego klonu.
- Numer wersji i buildu zgodny z wersją macOS; build rośnie przy każdej wysyłce.
- Raport testów wypełniony przez użytkownika według szablonu.
- Zaktualizowana macierz zgodności wobec wersji macOS.

## Testy funkcjonalne (użytkownik, build z TestFlight)

Sterowanie, safe area przy zimnym starcie, ikonę i symbole sprawdzono w etapach 01–03
(2026-11-04). Na buildzie z TestFlight zostaje szybki przegląd:

- zimny start, menu, wybór trudności, pełna runda na iPhonie i na iPadzie,
- ekran Credits z etapu 04,
- przerwania: połączenie przychodzące, Centrum sterowania, przejście do tła i powrót,
- ranking po zabiciu aplikacji i po aktualizacji przez TestFlight.

## Testy wydajności

| Pomiar | Limit | Kto |
|---|---|---|
| FPS przy 45 aktywnych wrogach (najstarsze wspierane urządzenie) | stabilne 60 | użytkownik (odczyt z nakładki lub Xcode) |
| Czas od uruchomienia do menu, w tym generowanie audio w `audio_lib.gd` | ≤ 3 s | użytkownik mierzy, agent poprawia przy przekroczeniu |
| Temperatura i bateria po 15 min gry | bez throttlingu skutkującego spadkiem poniżej 60 FPS | użytkownik |
| Rozmiar `.ipa` | cel < 100 MB | agent |

Generowanie SFX i muzyki przy starcie może trwać zauważalnie dłużej na telefonie.
Jeśli przekroczy limit, trzeba przenieść je do wątku w tle albo wypiec do zasobów.
Zmiana dotyczy tylko projektu iOS.

## Regresja macOS (agent)

- `./build.sh macos` przechodzi.
- Drzewo `project/` równe `PROJECT_TREE_BASELINE`, więc port iOS nie zmienił wersji macOS.
- `diff_from_macos.sh`: wszystkie zmiany macOS od `BASELINE` przeniesione albo opisane
  w macierzy zgodności.
- Ręczny test DualSense, klawiatury i myszy na macOS wykonuje użytkownik.

## TestFlight, App Review i wydanie (użytkownik)

1. Wysłanie buildu do App Store Connect i przejście przetwarzania.
2. Testy wewnętrzne w TestFlight na własnych urządzeniach.
3. Opcjonalnie testerzy zewnętrzni (wymaga skróconej recenzji Apple).
4. Zgłoszenie do App Review z notatkami z `review-notes.md`.
5. Przy odrzuceniu: treść odrzucenia trafia do agenta, a poprawki idą według tabeli
   ryzyk z etapu 04.
6. Publikacja wydania.

## Decyzja użytkownika

| Pole | Wartość |
|---|---|
| Status | `PLANNED` |
| Data | — |
| Wersja / build | — |
| Uwagi | — |

Status `APPROVED` nadaje wyłącznie użytkownik. Dopiero wtedy build trafia do App Store.
