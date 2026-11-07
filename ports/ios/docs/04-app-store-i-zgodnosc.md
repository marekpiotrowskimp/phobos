# iOS / iPadOS — App Store i zgodność

## Warunek rozpoczęcia

Etap 03 ma status `APPROVED` (2026-11-04). Decyzje z etapu 00 są podjęte:
- grafika wygenerowana przez AI,
- gra darmowa, status nie-tradera,
- nazwa sprawdzona.

## Cel

Przygotować wszystko, czego App Store Connect i App Review wymagają poza samą binarką,
żeby uniknąć odrzucenia.

## Podział pracy

| Kto | Co |
|---|---|
| **Agent** | kod w projekcie iOS (ekran Credits, privacy manifest, klucze `Info.plist`), gotowe teksty do wklejenia, odpowiedzi do kwestionariuszy, lista kontrolna i instrukcja krok po kroku |
| **Użytkownik** | wszystko w App Store Connect: rezerwacja nazwy, wypełnienie formularzy, zrzuty ekranu z urządzenia, publikacja polityki prywatności pod publicznym URL |

Materiały do wklejenia trafiają do katalogu `ports/ios/release/`:

| Plik | Zawartość |
|---|---|
| `metadata-pl.md`, `metadata-en.md` | nazwa, podtytuł (≤ 30 znaków), tekst promocyjny (≤ 170), opis (≤ 4000), słowa kluczowe (≤ 100 znaków), „Co nowego” |
| `privacy-policy.md` | polityka prywatności (PL i EN) do opublikowania, np. przez GitHub Pages |
| `app-store-connect-checklist.md` | kolejne ekrany App Store Connect z gotowymi odpowiedziami: prywatność, klasyfikacja wiekowa, export compliance, DSA, cena, dostępność, kontrolery |
| `screenshots.md` | wymagane rozmiary, lista ujęć (menu, rozgrywka, fala, ranking) i jak je zrobić na urządzeniu lub w symulatorze |

## Konto i status

- Apple Developer Program: konto, z którego wydano Nyndro (Team ID `JMMW48F6X4`).
- Status w UE (DSA): **nie-trader**. Gra jest darmowa, nie ma zakupów, reklam ani
  działalności gospodarczej.
- Cena: **darmowa (Free)**. Umowa Paid Apps i dane bankowo-podatkowe nie są potrzebne.

## Nazwa

- „Phobos” jest już zajęty w App Store przez aplikację użytkową Enginko SRL (sprawdzone 2026-11-04).
- Wybrana i zarezerwowana w App Store Connect: **„PHOBOS Survivor”**.
- Użytkownik rezerwuje nazwę przy tworzeniu aplikacji w App Store Connect. Nazwa pod ikoną
  (`CFBundleDisplayName`) zostaje „PHOBOS”, bo może się różnić od nazwy w sklepie.

## Prywatność

- `PrivacyInfo.xcprivacy` w paczce, z deklaracjami „required reason API” używanych przez
  Godot, np. znaczniki czasu plików i `UserDefaults`. Sprawdzić, co Godot 4.7 generuje sam,
  i uzupełnić braki.
- Etykieta prywatności w App Store Connect: „Data Not Collected”.
- Polityka prywatności: publiczny URL, wymagany także dla aplikacji bez zbierania danych.
  Agent przygotowuje tekst, a użytkownik go publikuje.

## Licencje i Credits

Ekran „Credits / Licencje” w menu gry iOS:

- PHOBOS, MIT, © 2026 Marek Piotrowski,
- Oxanium i Tektur, SIL OFL 1.1, pełny tekst z `assets/fonts/OFL-*.txt`,
- Godot Engine, MIT, oraz licencje komponentów zewnętrznych silnika
  (`Engine.get_license_info()` / `get_copyright_info()`),
- grafika: wygenerowana przez AI (Claude Code, Opus 5.5).

Ekran powstaje tylko w projekcie iOS. Wersja macOS jest chroniona, a ekran Credits dla niej
to osobna decyzja w ramach rozwoju `project/`.

## Metadane

| Pole | Treść |
|---|---|
| Nazwa | „PHOBOS Survivor” (patrz „Nazwa”) |
| Podtytuł | np. „Twin-stick survival shooter” |
| Kategoria | Games → Action (dodatkowa: Arcade) |
| Klasyfikacja wiekowa | kwestionariusz: przemoc fantastyczna/rysunkowa, brak realistycznej krwi (do weryfikacji, bo arena ma „ślady krwi”). Gotowe odpowiedzi w checkliście. |
| Kontrolery | zaznaczyć wsparcie dla kontrolerów; nie zaznaczać „Game Controller Required” |
| Zrzuty ekranu | iPhone 6.9" i iPad 13" (wymagane rozmiary), landscape; robi je użytkownik według `screenshots.md` |
| Opis, słowa kluczowe | PL i EN |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` w `Info.plist` |
| Cena | Free |

## Ryzyka odrzucenia

| Wytyczna | Ryzyko | Działanie |
|---|---|---|
| 2.1 Kompletność | crash, placeholdery | testy z etapu 05, usunięcie `concept_preview` z eksportu |
| 2.3 Metadane | zrzuty niezgodne z grą | zrzuty z prawdziwego urządzenia |
| 4.2 Minimalna funkcjonalność | niskie | pełna gra z menu i rankingiem |
| 4.3 Spam / kopie | niskie | oryginalna gra |
| 4.1 / 5.2 Nazwa i własność intelektualna | nazwa myląca z istniejącą aplikacją | nazwa z dopiskiem, grafika własna (AI) |
| Gra wymagająca pada | odrzucenie | sterowanie dotykowe z etapu 02 |

## Bramka akceptacji

- W projekcie iOS: ekran Credits, `PrivacyInfo.xcprivacy` i `ITSAppUsesNonExemptEncryption`
  są w eksportowanym buildzie (testy automatyczne).
- Materiały w `ports/ios/release/` są kompletne i mieszczą się w limitach znaków App Store.
- Drzewo `project/` (macOS) jest niezmienione.
- Akceptacja użytkownika.
