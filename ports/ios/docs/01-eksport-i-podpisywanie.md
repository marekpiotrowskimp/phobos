# iOS / iPadOS — eksport i podpisywanie

## Warunek rozpoczęcia

Etap 00 ma status `APPROVED`, a wybrany silnik to Godot.

## Cel

Uzyskać powtarzalny build iOS z linii poleceń: projekt Xcode, archiwum i plik `.ipa`
gotowy do TestFlight. Build macOS ma przy tym pozostać bez zmian.

## Utworzenie projektu iOS

1. Skopiować `project/` do `ports/ios/project/` bez `build/` i `.godot/`.
2. Zapisać hash commitu źródłowego w `ports/ios/BASELINE`.
3. Dodać `ports/ios/tools/diff_from_macos.sh`, który pokazuje zmiany w `project/` od `BASELINE`.
4. Sprawdzić, że drzewo `project/` dalej równa się `PROJECT_TREE_BASELINE`.

## Wymagania środowiska

- Pełny Xcode z App Store. `xcode-select -p` musi wskazywać `/Applications/Xcode.app/...`,
  a nie Command Line Tools.
- Szablony eksportu Godot 4.7.1. Plik `ios.zip` pochodzi z tej samej paczki `.tpz`, którą
  `build.sh` już pobiera dla macOS.
- Konto Apple Developer Program, Team ID (10 znaków) i certyfikat Apple Distribution w pęku kluczy.
- Bundle ID zarejestrowany w App Store Connect (decyzja z etapu 00).

## Stan konta i środowiska (sprawdzone 2026-11-03)

Na podstawie repozytorium `nyndro-ios` (aplikacja Nyndro, wydana w App Store):

| Element | Stan |
|---|---|
| Apple Developer Program | aktywne konto, z którego wydano Nyndro v1.01 (darmowa) |
| Team ID | `JMMW48F6X4` |
| Schemat bundle ID | `com.marek.piotrowski.<app>`, zgodny z `com.marek.piotrowski.phobos` |
| Podpisywanie | `CODE_SIGN_STYLE: Automatic` |
| Xcode | 26.2, `xcode-select` wskazuje pełny Xcode |
| Certyfikaty w pęku kluczy | 3× Apple Development, brak lokalnego Apple Distribution (przy automatycznym podpisywaniu Xcode użyje certyfikatu zarządzanego w chmurze) |
| Wzorce do ponownego użycia | `release_1_01/RELEASE_CHECKLIST.md`, `APP_STORE_INFO.md`, polityka prywatności i strona wsparcia na GitHub Pages |

Team ID nie jest tajny, bo widać go w każdej podpisanej aplikacji. Jest zapisany wprost
w presetach, bo Godot nie czyta go ze zmiennej środowiskowej.

## Presety eksportu

`ports/ios/project/export_presets.cfg` ma dwa presety, `iOS` i `iOS Xcode`. W kopii nie ma
presetu macOS.

| Opcja | Wartość |
|---|---|
| `application/app_store_team_id` | `JMMW48F6X4` |
| `application/bundle_identifier` | `com.marek.piotrowski.phobos` |
| `application/short_version`, `version` | zgodne z wersją macOS |
| `application/targeted_device_family` | iPhone i iPad |
| `application/min_ios_version` | minimum wspierane przez Godot 4.7 i wymagane przez App Store |
| `orientation` | tylko landscape left i landscape right |
| `icons/*` | ikona 1024×1024 bez kanału alfa, generowana z `icon.svg` |
| `storyboard/*` | ciemne tło (kolor `default_clear_color`) i logo |
| `privacy/*` | brak uprawnień: kamera, mikrofon, lokalizacja, zdjęcia nieużywane |
| `exclude_filter` | taki sam jak w macOS (koncepty i `concept_preview`) |
| `include_filter` | `assets/fonts/*.txt` (licencje OFL) |

## Renderer

- Projekt używa `forward_plus`. Na iOS działa on przez Metal, ale jest cięższy.
- Pierwszy test: Forward+ na najstarszym wspieranym urządzeniu przy 45 aktywnych wrogach.
- Jeśli nie osiągnie 60 FPS, przejść na `mobile` tylko dla iOS przez
  `rendering/renderer/rendering_method.mobile`. Sprawdzić wtedy wygląd shaderów
  `floor.gdshader` i `vignette.gdshader` oraz poświat.

## Cele `build.sh`

| Cel | Preset | Wynik | Wymaga |
|---|---|---|---|
| `./build.sh ios-xcode` | `iOS Xcode` (`export_project_only=true`) | `ports/ios/project/build/xcode/PHOBOS.xcodeproj` | pełny Xcode |
| `./build.sh ios` | `iOS` (archiwum i eksport App Store) | `ports/ios/project/build/PHOBOS.ipa` | pełny Xcode, konto Apple, podpis |

Kolejność kroków:

1. Sprawdzić pełny Xcode. Jeśli go brak, zakończyć z instrukcją `xcode-select -switch`.
2. Sprawdzić szablon `ios.zip`. Jeśli go brak, pobrać paczkę szablonów (`ensure_export_templates ios.zip`).
3. Przy pierwszym uruchomieniu zaimportować zasoby projektu iOS.
4. Wykonać `godot --headless --path ports/ios/project --export-release <preset> <wynik>`.
   W celu `ios` Godot sam wykonuje `xcodebuild archive` i eksport `.ipa`.

Cel `all` nadal buduje tylko macOS i Amigę. iOS wymaga konta Apple, więc nie jest domyślny.

Testy etapu znajdują się w katalogu `ports/ios/tests/`. Test podpisanego `.ipa` uruchamia się
tylko z `PHOBOS_IOS_SIGNED=1`.

## Bramka akceptacji

- Build z czystego klonu daje `.ipa` lub, bez Team ID, projekt Xcode.
- Aplikacja uruchamia się na fizycznym iPhonie przez Xcode, nawet bez sterowania dotykowego.
- `./build.sh macos` daje identyczny wynik jak przed zmianą, a drzewo `project/` jest niezmienione.
- Akceptacja użytkownika.
