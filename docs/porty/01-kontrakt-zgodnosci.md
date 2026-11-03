# Porty retro — kontrakt zgodności

## Źródło prawdy

Punktem odniesienia jest działająca wersja macOS, w szczególności:

- `project/scripts/autoloads/balance.gd` — parametry walki, fal, dropów i punktacji,
- `project/scripts/autoloads/game_state.gd` — trudności, ranking i zapis,
- `project/scripts/main.gd` — przebieg rundy, director oraz menu,
- `project/scripts/player.gd`, `enemy.gd` i `pickup.gd` — zachowanie obiektów,
- `project/scripts/hud.gd` — komunikaty i struktura interfejsu.

Dokumenty starszych etapów opisują intencję projektu, ale w przypadku różnicy pierwszeństwo
ma aktualne zachowanie gry i wartości w kodzie.

## Mechaniki obowiązkowe

Każdy port zachowuje:

- jedną arenę widoczną w całości,
- niezależny ruch i celowanie w ośmiu kierunkach,
- ciągły ogień hitscan z czytelnym sygnałem strzału i trafienia,
- kontaktowe obrażenia, zdrowie i krótki czas niewrażliwości,
- fale z przerwą, telegraphem i rosnącą presją,
- czerwony, bursztynowy i fioletowy wariant przeciwnika,
- leczenie, Overdrive i mechanizm litości,
- trzy poziomy trudności zmieniające wyłącznie częstotliwość dropów,
- punkty, numer fali, liczbę zabójstw i ekran końca rundy,
- wpisywanie trzech inicjałów oraz lokalny Top 10 dla każdej trudności,
- pauzę, wyciszenie i szybki restart,
- polskie komunikaty oraz wymagane znaki diakrytyczne.

## Sterowanie

Każdy port udostępnia dwa tryby:

1. Klawiatura odpowiada za ruch, mysz za celowanie, a przycisk myszy za strzał.
2. Joystick odpowiada za ruch, klawiatura za kierunek celowania i strzał.

Amiga korzysta ze standardowej myszy zgodnej z A500. Wersja C64 obsługuje mysz zgodną
z Commodore 1351. Dokładny układ klawiszy zostanie wybrany w technicznym PoC każdej
platformy po teście ergonomii na prawdziwej klawiaturze.

## Dozwolone adaptacje

Po osobnej akceptacji można zmienić:

- rozdzielczość, paletę, liczbę klatek animacji i sposób rysowania areny,
- maksymalną liczbę aktywnych przeciwników i efektów,
- częstotliwość renderowania przy zachowaniu responsywnego wejścia,
- format muzyki i efektów dźwiękowych,
- czas fal lub tempo spawnu, jeśli zachowują porównywalny przebieg presji,
- format danych rankingu wynikający z ograniczeń nośnika.

Nie wolno bez osobnej decyzji usuwać wariantów przeciwników, dropów, trudności,
rankingu ani niezależnego celowania.

## Macierz zgodności

Każdy port prowadzi tabelę:

| Element | macOS | Port | Status | Powód odstępstwa | Akceptacja |
|---|---|---|---|---|---|
| Przykład: limit przeciwników | 60 w puli | Do ustalenia w PoC | Otwarte | Budżet CPU/RAM | — |

Status może mieć wartość `ZGODNE`, `DOSTOSOWANE`, `BRAK` lub `OTWARTE`. Wydanie nie może
zawierać pozycji `BRAK` ani `OTWARTE` dla mechanik obowiązkowych.

## Zasoby i licencje

- Konwersja korzysta z zatwierdzonych grafik w `project/assets/`.
- Każdy przetworzony plik ma manifest ze ścieżką źródła, checksumą i ustawieniami konwersji.
- Tektur i Oxanium podlegają SIL OFL 1.1; użycie danych pochodnych zachowuje wymagane noty.
- Przed publiczną dystrybucją trzeba potwierdzić prawa do kodu, grafiki, muzyki i efektów.
- Zasoby tymczasowe i koncepty nie trafiają do obrazu ADF ani D64.

## Wspólne testy akceptacyjne

- Zimny start z docelowego obrazu nośnika.
- Oba tryby sterowania na prawdziwym sprzęcie.
- Trzy pełne rundy bez zawieszenia, uszkodzenia ekranu i utraty wejścia.
- Czytelne rozróżnienie gracza, wariantów przeciwnika i dropów bez HUD.
- Poprawna punktacja, fala, trudność, Overdrive i game over.
- Zapis, ponowne uruchomienie i odczyt Top 10.
- Stabilna praca w standardzie PAL wybranej platformy.
- Brak zmian oraz regresji w wersji Godot/macOS.
