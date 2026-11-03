# iOS / iPadOS — założenia, licencje i platformy

## Status

`APPROVED` (2026-11-03)

Decyzje zatwierdzone przez użytkownika. Kolejne etapy wymagają osobnej akceptacji.
Stan prawny i cennikowy sprawdzony 2026-11-03. Przed wydaniem trzeba go sprawdzić ponownie.

## Target

- iPhone i iPad, orientacja pozioma (landscape left/right).
- Dystrybucja przez App Store, wersje testowe przez TestFlight.
- Podstawowe sterowanie dotykowe. Pad (DualSense, Xbox, MFi) jest opcjonalnym dodatkiem.
- Ta sama rozgrywka co wersja macOS według `docs/porty/01-kontrakt-zgodnosci.md`.
- Możliwy w przyszłości PS5, wyłącznie po spełnieniu bramki Sony (sekcja „PS5”).

## Prawa do zawartości gry

| Element | Licencja / źródło | Wniosek |
|---|---|---|
| Kod `project/`, `ports/` | MIT, © 2026 Marek Piotrowski | Wolno go przenosić na dowolny silnik i sprzedawać w App Store. MIT nie koliduje z warunkami Apple, w przeciwieństwie do GPL. |
| Fonty Oxanium, Tektur | SIL OFL 1.1 (`project/assets/fonts/OFL-*.txt`) | Wolno je osadzić w płatnej grze. Tekst licencji musi być dostępny w aplikacji (ekran Credits). Nie wolno sprzedawać samych fontów. |
| Efekty dźwiękowe i muzyka | Synteza proceduralna w `project/scripts/autoloads/audio_lib.gd` | Własne, bez obcych praw. |
| Sprite'y PNG/SVG (`project/assets/sprites/`) | Wygenerowane przez AI (Claude Code, model Opus 5.5) w trakcie pracy nad projektem | Warunki Anthropic przekazują prawa do wygenerowanych treści użytkownikowi, więc komercyjne użycie jest dozwolone. Treść wygenerowana w całości przez AI może nie podlegać ochronie prawa autorskiego, więc inni mogliby ją kopiować; nie blokuje to jednak publikacji. Fakt użycia AI trzeba odnotować w Credits i w deklaracji App Store Connect, jeśli Apple o to zapyta. |
| Nazwa „PHOBOS” | — | Nazwa w App Store musi być unikalna. Sprawdzić dostępność w App Store Connect i bazach znaków towarowych (EUIPO, USPTO). W razie konfliktu użyć podtytułu, np. „PHOBOS: Arena”. |
| Bundle ID | **`com.marek.piotrowski.phobos`** (decyzja 2026-11-03) | Zastępuje `com.phobos.game`. Dotyczy tylko projektu iOS; preset macOS w `project/` pozostaje bez zmian. Po pierwszym wydaniu nie można go zmienić. |
| Ikona `project/icon.svg` | wygenerowana tak samo jak sprite'y | Status prawny jak sprite'y. iOS wymaga wersji 1024×1024 bez przezroczystości. |

## Wybór silnika: Unity czy Godot

| Kryterium | Godot 4.7 (obecny) | Unity 6 |
|---|---|---|
| Licencja silnika | MIT, bez opłat | Personal darmowy do 200 tys. USD przychodu i finansowania w ciągu 12 miesięcy. Wyżej Pro. Runtime Fee anulowano. |
| Splash screen | brak | opcjonalny w Unity 6 |
| Eksport iOS / iPadOS | natywny (projekt Xcode) | natywny (projekt Xcode) |
| Koszt portu | preset eksportu, warstwa dotyku i layout | przepisanie ok. 2,7 tys. linii GDScript na C#, scen `.tscn`, 2 shaderów i syntezy audio |
| Spójność z macOS | jedno źródło dla macOS i iOS | dwie implementacje do utrzymania, ryzyko rozjazdu balansu |
| PS5 | przez płatne W4 Consoles lub studio portujące, po akceptacji Sony | Unity Pro albo klucz licencyjny od Sony i dodatek platformowy, po akceptacji Sony |

**Decyzja (2026-11-03): Godot.** iOS i iPadOS nie wymagają Unity. Unity dawałoby przewagę
dopiero przy konsolach, a i tam bramką jest Sony, nie silnik. Ścieżka PS5 to W4 Consoles
(sekcja „PS5”).

Gałąź `feature/unity-port` przemianować na `port/ios`.

## Wymagania App Store (niezależne od silnika)

- Członkostwo w Apple Developer Program: 99 USD rocznie.
- Mac z pełnym Xcode. Same Command Line Tools nie wystarczą.
- Certyfikat dystrybucyjny, profil provisioning, App Store Connect i TestFlight.
- **Gra na iPhonie i iPadzie nie może wymagać pada.** Sterowanie dotykowe jest obowiązkowe,
  a kontroler może je tylko uzupełniać. Opcja „Game Controller Required” istnieje wyłącznie
  dla tvOS i visionOS.
- Privacy manifest (`PrivacyInfo.xcprivacy`) z deklaracją używanych API.
- Kwestionariusz prywatności: „Data Not Collected”, bo gra nie ma sieci, analityki ani kont,
  a ranking jest lokalny.
- Klasyfikacja wiekowa: przemoc fantastyczna wobec potworów.
- Export compliance: aplikacja nie używa szyfrowania poza systemowym, więc
  `ITSAppUsesNonExemptEncryption = NO`.
- UE (Digital Services Act): wymagana deklaracja statusu tradera.
  - Gra płatna: trader, a adres, telefon i e-mail są publicznie widoczne w App Store.
  - Gra darmowa bez zakupów i bez działalności gospodarczej: można zadeklarować status nie-tradera.
- Ekran licencji w aplikacji: MIT dla gry, OFL dla fontów, informacja o Godot (MIT) i jego
  bibliotekach zależnych.

## PS5

- Każdy silnik wymaga najpierw akceptacji Sony: PlayStation Partners, NDA, devkit i certyfikacja TRC.
- Unity Personal nie buduje na PS5. Potrzebny jest Unity Pro albo Preferred Platform License Key
  od Sony oraz dodatek platformowy.
- Godot oficjalnie nie wspiera konsol, bo SDK są objęte NDA. PS5 obsługuje komercyjne
  W4 Consoles (Godot 4.3+, dostęp po certyfikacji u Sony) lub zewnętrzne studia portujące.
- Kod gry na licencji MIT nie stoi na przeszkodzie. Kodu powiązanego z SDK Sony nie wolno
  publikować w publicznym repozytorium, więc port PS5 musiałby żyć w prywatnym repo lub
  osobnym module.
- **Decyzja (2026-11-03):** PS5 wraca jako opcja warunkowa. Nie ma prac w kodzie, dopóki
  Sony nie zaakceptuje projektu. Planowana ścieżka to Godot + W4 Consoles.
  Pierwszy krok: rejestracja w PlayStation Partners.

## Macierz platform

| Platforma | Silnik / technologia | Status | Bramka |
|---|---|---|---|
| macOS | Godot 4.7 | `RELEASED` (build lokalny) | — |
| iOS / iPadOS | Godot 4.7, osobny projekt `ports/ios/project/` | `IN_PROGRESS` | akceptacja kolejnych etapów |
| Amiga 500 | C, m68k-amigaos | `IN_PROGRESS` | akceptacja użytkownika |
| Commodore 64 | — | `BLOCKED` | `APPROVED` Amigi |
| PS5 | Godot 4.7 + W4 Consoles | `CONDITIONAL` | akceptacja Sony (PlayStation Partners) |

## Izolacja od wersji macOS

Port iOS to **osobny projekt Godot** w `ports/ios/project/`. Wersja macOS w `project/`
pozostaje nietknięta, tak jak przy porcie Amigi. Obowiązują zasady z
`docs/porty/00-plan-i-bramki.md`:

- Projekt iOS powstaje w etapie 01 jako jednorazowa kopia `project/` na commicie bazowym.
  Commit zapisujemy w `ports/ios/BASELINE`.
- Wszystkie zmiany iOS trafiają wyłącznie do `ports/ios/`: preset eksportu, sterowanie
  dotykowe, layout, ekran licencji.
- Po każdym etapie sprawdzamy, że drzewo `project/` jest identyczne z
  `PROJECT_TREE_BASELINE`.
- Zmiany w wersji macOS, np. balansu, przenosi się do iOS świadomie i ręcznie. Narzędzie
  `ports/ios/tools/diff_from_macos.sh` pokazuje różnice `project/` względem `BASELINE`,
  żeby nic nie umknęło.
- Rozjazd rozgrywki względem macOS wymaga wpisu w macierzy zgodności
  (`docs/porty/01-kontrakt-zgodnosci.md`).

## Plan etapów

| Etap | Dokument | Zakres |
|---|---|---|
| 00 | ten plik | licencje, silnik, platformy |
| 01 | `01-eksport-i-podpisywanie.md` | preset iOS, Xcode, podpis, `build.sh ios` |
| 02 | `02-sterowanie-dotykowe.md` | wirtualne drążki i obsługa pada |
| 03 | `03-ui-safe-area-i-proporcje.md` | layout iPhone/iPad, safe area, zapis |
| 04 | `04-app-store-i-zgodnosc.md` | metadane, prywatność, licencje, trader |
| 05 | `05-build-testy-i-akceptacja.md` | TestFlight, testy na sprzęcie, wydanie |

## Decyzje użytkownika

| # | Pytanie | Odpowiedź (2026-11-03) |
|---|---|---|
| 1 | Silnik | **Godot** |
| 2 | Pochodzenie sprite'ów i ikony | **Wygenerowane przez AI** (Claude Code, Opus 5.5) |
| 3 | Gra płatna czy darmowa | **Odłożone.** Trzeba zdecydować przed etapem 04, bo od tego zależą status tradera i umowa Paid Apps. Nie blokuje etapów 01–03. |
| 4 | Bundle ID | **`com.marek.piotrowski.phobos`**. Nazwę w sklepie sprawdzimy w etapie 04. |
| 5 | Czy port iOS może zmieniać `project/` | **Nie.** Wersja macOS jest chroniona, iOS to osobny projekt w `ports/ios/project/`. |
| 6 | PS5 jako opcja warunkowa | **Tak** |

## Bramka akceptacji

Etap 00 zamknięty 2026-11-03. Gałąź robocza: `port/ios`. Następny krok to etap 01, który wymaga osobnej akceptacji.

## Źródła

- [Unity — pricing updates](https://unity.com/pricing-updates)
- [Unity Personal](https://unity.com/products/unity-personal)
- [Unity × PlayStation](https://unity.com/solutions/playstation)
- [Godot — Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot — Console support](https://docs.godotengine.org/en/stable/tutorials/platform/consoles.html)
- [W4 Consoles](https://www.w4games.com/w4consoles)
- [Apple HIG — Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
