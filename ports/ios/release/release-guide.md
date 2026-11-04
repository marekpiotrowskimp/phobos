# PHOBOS iOS — instrukcja wydania krok po kroku

Wysyłkę, TestFlight, App Review i publikację robisz sam (decyzja nr 7 z etapu 00).
Ta instrukcja prowadzi od czystego repozytorium do gry w App Store. Przed wysłaniem do
recenzji przejdź też listę [`release-checklist.md`](release-checklist.md).

Wymagania: pełny Xcode (nie same Command Line Tools), zalogowane konto Apple Developer w Xcode
(Team `JMMW48F6X4`) oraz aplikacja utworzona w App Store Connect według
[`app-store-connect-checklist.md`](app-store-connect-checklist.md).

## 1. Wersja i build

Każda wysyłka do App Store Connect musi mieć **wyższy numer buildu** niż poprzednia. Wersja
sklepowa idzie za wersją macOS (dziś `0.1.0`).

```sh
ports/ios/tools/set_version.sh 0.1.0 2     # następny build: 2, 3, 4…
```

Narzędzie zmienia oba presety iOS i odrzuca build równy lub niższy od obecnego. Pierwszy build
ma numer `1` (już ustawiony). Po zmianie zrób commit presetów.

## 2. Build

```sh
bash ports/ios/tests/run_tests.sh          # wszystkie testy portu muszą być zielone
./build.sh ios                             # → ports/ios/project/build/PHOBOS.ipa
```

`./build.sh ios` eksportuje projekt Godota, archiwizuje go w Xcode i podpisuje do
dystrybucji w App Store. Wynik to `ports/ios/project/build/PHOBOS.ipa`.

Jeśli wolisz pracować w Xcode: `./build.sh ios-xcode`, otwórz
`ports/ios/project/build/xcode/PHOBOS.xcodeproj` i wybierz **Product → Archive**.

## 3. Wysyłka

Do wyboru jedna z dwóch dróg:

- **Transporter** (darmowa aplikacja Apple z Mac App Store): zaloguj się, przeciągnij
  `PHOBOS.ipa` i kliknij **Deliver**.
- **Xcode Organizer** (po Product → Archive): Window → Organizer → wybierz archiwum →
  **Distribute App → App Store Connect → Upload**.

Po kilku–kilkunastu minutach build pojawi się w App Store Connect (zakładka TestFlight) ze
statusem „Processing”, a potem „Ready to Test”. Pytanie o szyfrowanie nie powinno się pojawić,
bo build deklaruje `ITSAppUsesNonExemptEncryption = NO`.

## 4. TestFlight

1. App Store Connect → TestFlight → **Internal Testing** → dodaj siebie jako testera.
2. Zainstaluj aplikację **TestFlight** na iPhonie i iPadzie i pobierz build.
3. Przejdź szablon [`test-report.md`](test-report.md) i wypełnij go (FPS, start, rundy,
   LICENCJE, przerwania, ranking).
4. Testerzy zewnętrzni są opcjonalni; wymagają skróconej recenzji Apple (Beta App Review).

Jeśli coś nie działa: opisz problem, a poprawka przejdzie przez /spec → /implement, potem
`set_version.sh` z kolejnym buildem i ponowna wysyłka.

## 5. App Review

1. **Scal gałąź `port/ios` do `main` i wypchnij.** Dopiero wtedy działają adresy polityki
   prywatności i wsparcia (pliki w `ports/ios/release/` na `main`). Sprawdź je przez `curl`
   z listy kontrolnej.
2. App Store Connect → aplikacja → wersja 0.1.0 → sekcja **Build** → wybierz przetestowany build.
3. Uzupełnij metadane, zrzuty, prywatność i klasyfikację wiekową według
   [`app-store-connect-checklist.md`](app-store-connect-checklist.md).
4. W **App Review Information → Notes** wklej tekst z [`review-notes.md`](review-notes.md).
   Sign-in required: **No**.
5. **Version Release:** wybierz „Manually release this version”, żeby sam zdecydować o dniu
   premiery (albo automatyczne wydanie po akceptacji).
6. **Add for Review → Submit for Review.** Recenzja trwa zwykle 1–3 dni.

## 6. Wydanie

Po statusie „Pending Developer Release” kliknij **Release This Version**. Gra pojawia się w
sklepie zwykle w ciągu kilku godzin. Następnie:

- wpisz wersję i build w [`test-report.md`](test-report.md) i ustaw w dokumencie
  `ports/ios/docs/05-build-testy-i-akceptacja.md` status `APPROVED` z datą,
- oznacz commit wydania tagiem, np. `git tag ios-0.1.0-1`.

## Po odrzuceniu

1. Skopiuj treść odrzucenia z Resolution Center (numer wytycznej i opis).
2. Przekaż ją agentowi. Typowe przyczyny i działania są w tabeli ryzyk w
   `ports/ios/docs/04-app-store-i-zgodnosc.md`.
3. Jeśli wystarczy zmiana metadanych, popraw je w App Store Connect i wyślij ponownie bez
   nowego buildu.
4. Jeśli trzeba zmienić grę: poprawka, `set_version.sh` z wyższym buildem, kroki 2–5.
5. Z decyzją się nie zgadzasz? Odpowiedz w Resolution Center albo złóż odwołanie (App Review
   Board).
