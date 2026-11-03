# iOS / iPadOS — App Store i zgodność

## Warunek rozpoczęcia

Etap 03 ma status `APPROVED`, a decyzje z etapu 00 (prawa do grafiki, model dystrybucji,
nazwa) są podjęte.

## Cel

Przygotować wszystko, czego App Store Connect i App Review wymagają poza samą binarką,
żeby uniknąć odrzucenia.

## Konto i rejestracja

- Apple Developer Program (99 USD rocznie): konto indywidualne albo firmowe. Przy koncie
  firmowym potrzebny jest numer D-U-N-S.
- Status tradera w UE (DSA):
  - trader: adres, telefon i e-mail publicznie w sklepie,
  - nie-trader: tylko gra darmowa, bez zakupów i bez działalności gospodarczej.
- Umowa Paid Apps i dane bankowo-podatkowe tylko przy grze płatnej.

## Prywatność

- `PrivacyInfo.xcprivacy` w paczce. Zawiera deklaracje „required reason API” używanych
  przez Godot, np. znaczniki czasu plików i `UserDefaults`. Sprawdzić, co Godot 4.7
  generuje sam, i uzupełnić braki.
- Etykieta prywatności w App Store Connect: „Data Not Collected”.
- Polityka prywatności: publiczny URL (wymagany także dla aplikacji bez zbierania danych).
  Może to być strona w repozytorium GitHub.

## Licencje i Credits

Ekran „Credits / Licencje” w menu gry:

- PHOBOS, MIT, © 2026 Marek Piotrowski,
- Oxanium i Tektur, SIL OFL 1.1, pełny tekst z `project/assets/fonts/OFL-*.txt`,
- Godot Engine, MIT, oraz licencje komponentów zewnętrznych silnika
  (`Engine.get_license_info()` / `get_copyright_info()`),
- grafika: wygenerowana przez AI (Claude Code, Opus 5.5).

Ekran powstaje tylko w projekcie iOS. Wersja macOS także rozpowszechnia fonty OFL. Teksty
licencji są już dołączane do paczki (`include_filter`), a ekran Credits dla macOS to
osobna decyzja w ramach rozwoju `project/`.

## Metadane

| Pole | Treść |
|---|---|
| Nazwa | ustalona w etapie 00 (maks. 30 znaków) |
| Podtytuł | np. „Twin-stick survival shooter” |
| Kategoria | Games → Action (dodatkowa: Arcade) |
| Klasyfikacja wiekowa | kwestionariusz: przemoc fantastyczna/rysunkowa, brak krwi realistycznej (do weryfikacji, bo arena ma „ślady krwi”) |
| Kontrolery | zaznaczyć wsparcie dla kontrolerów; nie zaznaczać „Game Controller Required” |
| Zrzuty ekranu | iPhone 6.9" i iPad 13" (wymagane rozmiary), landscape |
| Opis, słowa kluczowe | PL i EN |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` w `Info.plist` |
| Cena | decyzja z etapu 00 |

## Ryzyka odrzucenia

| Wytyczna | Ryzyko | Działanie |
|---|---|---|
| 2.1 Kompletność | crash, placeholdery | testy z etapu 05, usunięcie `concept_preview` z eksportu |
| 2.3 Metadane | zrzuty niezgodne z grą | zrzuty z prawdziwego urządzenia |
| 4.2 Minimalna funkcjonalność | niskie | pełna gra z menu i rankingiem |
| 4.3 Spam / kopie | niskie | oryginalna gra |
| 5.2 Własność intelektualna | grafika lub nazwa bez praw | bramka praw z etapu 00 |
| Gra wymagająca pada | odrzucenie | sterowanie dotykowe z etapu 02 |

## Bramka akceptacji

- Wypełniona lista kontrolna z tego dokumentu.
- Ekran Credits działa na iOS i macOS.
- Akceptacja użytkownika.
