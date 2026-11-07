# Lista kontrolna przed „Submit for Review”

Odhacz po kolei. Szczegóły kroków są w [`release-guide.md`](release-guide.md).

## Build

- [ ] Numer buildu wyższy niż ostatnio wysłany: `ports/ios/tools/set_version.sh 0.1.0 <build>`, a zmiana presetów jest w commicie.
- [ ] Wszystkie testy portu zielone: `bash ports/ios/tests/run_tests.sh`.
- [ ] Wersja macOS nadal się buduje: `./build.sh macos` (port iOS nie zmienia `project/`).
- [ ] `./build.sh ios` dał `ports/ios/project/build/PHOBOS.ipa`, a build jest w App Store Connect jako „Ready to Test”.

## Testy

- [ ] TestFlight na iPhonie i iPadzie przeszedł, a raport w [`test-report.md`](test-report.md) jest wypełniony (FPS, start, rundy, LICENCJE, przerwania, ranking).

## Adresy i treści

- [ ] Gałąź `port/ios` scalona do `main` i wypchnięta.
- [ ] Polityka prywatności otwiera się bez logowania (oczekiwany kod 200):
      `curl -s -o /dev/null -w "%{http_code}\n" https://marekpiotrowskimp.github.io/phobos/privacy_policy.html`
- [ ] Strona wsparcia otwiera się bez logowania (oczekiwany kod 200):
      `curl -s -o /dev/null -w "%{http_code}\n" https://marekpiotrowskimp.github.io/phobos/support.html`
- [ ] Strony HTML w `docs/` (`support*.html`, `privacy_policy*.html`) mają tę samą treść co
      [`support.md`](support.md) i [`privacy-policy.md`](privacy-policy.md) — po zmianie tekstu popraw oba miejsca.
- [ ] Wszystkie ekrany z [`app-store-connect-checklist.md`](app-store-connect-checklist.md) wypełnione: nazwa, cena Free, prywatność „Data Not Collected”, klasyfikacja wiekowa, DSA non-trader, eksport.
- [ ] Teksty PL i EN wklejone z `metadata-pl.md` i `metadata-en.md`.
- [ ] Zrzuty iPhone 6.9" i iPad 13" dodane według [`screenshots.md`](screenshots.md).
- [ ] **Nie** zaznaczono „Game Controller Required” (gra działa dotykiem).

## Recenzja

- [ ] W App Review Information wklejone notatki z [`review-notes.md`](review-notes.md), a Sign-in required ustawione na „No”.
- [ ] Wybrany właściwy build w sekcji Build wersji 0.1.0.
- [ ] Wybrany sposób wydania: ręczny („Manually release this version”) albo automatyczny.
