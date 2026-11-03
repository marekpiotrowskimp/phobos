# PHOBOS — Opis Projektu

## Wizja

Nowoczesny twin-stick survival shooter inspirowany klasyką **Alien Phobia** (Wah-Software, DOS, 1997).
Rdzeń inspiracji: pojedyncza arena, napływający obcy ze wszystkich stron, narastająca presja i walka
o jak najdłuższe przetrwanie. Oprawa jest **nowoczesna** — bez piksel-artu, bez filtrów retro.

> **Zasada przewodnia:** jeśli po tygodniu łapiesz się na tym, że odpalasz to dla przyjemności,
> to znaczy, że projekt ma sens.

## Kierunek artystyczny

**Bio-industrial horror:** ciemna, metalowa arena przejmowana przez organiczne formy. Gracz jest
grafitowym egzoszkieletem z cyjanowym wizjerem i asymetrycznym karabinem. Przeciwnicy są krwistymi,
opancerzonymi organizmami z widocznym, świecącym rdzeniem. Grafika jest nowoczesna, wysokiej
rozdzielczości i czytelna w rzucie z góry; bez pixel-artu i bez zastępczych brył geometrycznych.

Podstawowe zasoby powstają jako autorskie SVG z przezroczystością, a w grze są wyświetlane jako
animowane sprite'y osadzone w świecie 3D. Kolizje pozostają niezależne od rozmiaru grafiki.

## Cel

Przetrwać jak najdłużej. Odpierać coraz trudniejsze fale, zbierać ulepszenia, bić własne rekordy.

## Koncept Rozgrywki

- **Sterowanie (pad):** lewa gałka — ruch, prawa gałka — celowanie, R2/L2 — strzał.
- **Arena:** jedna, zwarta, widoczna w całości na ekranie.
- **Postać:** jedna na start.
- **Wróg:** jeden typ, który napływa z krawędzi areny i atakuje.
- **Broń:** jedna, automatyczna, hitscan z widocznym tracertem.
- **HUD:** pasek zdrowia, licznik punktów, numer fali.
- **Fale:** trudność rośnie (liczba, prędkość, częstotliwość spawnu).
- **Dropy:** leczenie + czasowy tryb *Overdrive* (wzmożona siła ognia).
- **Przegrana:** zdrowie do zera → ekran wyniku → szybki restart.

## Wymagania techniczne

- Silnik: **Godot 4.x** (4.7.1), GDScript, renderer Forward+.
- Platforma docelowa prototypu: **macOS** (Apple Silicon, arm64).
- Kontroler: Sony DualSense (macOS, USB / Bluetooth), fallback klawiatura.
- Cel wydajności: **60 FPS** przy maksymalnej zakładanej liczbie wrogów.
- Dźwięk: proceduralny (AudioStreamGenerator / synteza) + warstwowa muzyka dark synth.

## Zakres prototypu (MVP, tydzień)

| W | Zakres |
|---|--------|
| Tak | 1 arena, 1 postać, 1 typ wroga, 1 broń, zdrowie, punkty, fale, dropy, game over, restart |
| Tak | Efekty wizualne (strzał, trafienie, śmierć), rumble, dźwięki |
| Tak | Warstwowa muzyka: spokój → narastanie → wysoka intensywność, przerwa po fali |
| Tak | Build macOS `.app` |
| Nie | Boss, druga broń, wiele aren, fabuła, progresja trwała, multiplayer, kod PS5 |

## Zakres iteracji v0.2

- Menu główne i wybór poziomu: Łatwy, Normalny lub Trudny.
- Trudność zmienia wyłącznie częstotliwość leczenia i Overdrive; wynik nie ma mnożnika.
- Lokalny ranking Top 10 na trudność, jeden ekran z filtrem oraz wpisywanie trzech inicjałów.
- Rekord zawiera wynik, trudność, falę, zabicia, czas i datę.
- Trzy warianty punktowe tego samego skorpiona: czerwony, bursztynowy i fioletowy.

## Zasada realizacji etapów

Każdy etap lub podetap wykonawczy rozpoczyna się dopiero po osobnej akceptacji użytkownika.
Zatwierdzenie planu nie oznacza automatycznej zgody na realizację wszystkich etapów.

## Przyszłość (po decyzji GO)

- Kontynuacja projektu w Godot z platformą docelową macOS.
- Port PS5 został świadomie porzucony; projekt nie zakłada SDK Sony, devkitu ani certyfikacji konsolowej.
- Osobne porty retro powstają kolejno na Amigę 500, a po jej akceptacji na Commodore 64.
- Prototyp = specyfikacja: zachowujemy modele, dźwięk, parametry balansu i wiedzę.

## Ścieżka decyzyjna (koniec tygodnia)

- **GO** — projekt ma sens, kontynuujemy rozwój w Godot na macOS.
- **ITERATE** — fun jest blisko, brakuje konkretnych elementów (spisanych).
- **STOP** — nie ma frajdy mimo poprawek, projekt nie ma sensu.

## Struktura repozytorium

```text
docs/
├── 00-opis-projektu.md
├── porty/
│   ├── 00-plan-i-bramki.md
│   └── 01-kontrakt-zgodnosci.md
└── etapy/
    ├── 01-fundament-techniczny.md
    ├── 02-sterowanie-i-walka.md
    ├── 03-przeciwnik-i-fale.md
    ├── 04-pickupy-hud-i-petla-gry.md
    ├── 05-game-feel-i-audio.md
    ├── 06-balans-i-build-macos.md
    ├── 07-test-frajdy-i-decyzja.md
    ├── 08-oprawa-i-presja.md
    └── 09-menu-ranking-i-warianty.md
project/
├── project.godot
├── scenes/       # sceny Godot (.tscn)
├── scripts/      # skrypty GDScript
├── shaders/      # shadery (glow, distort)
└── assets/       # fonty, audio, zasoby
ports/
├── amiga500/     # osobny kod, zasoby, narzędzia, testy i dokumentacja
└── commodore64/  # zablokowany do czasu akceptacji portu Amigi 500
```

## Ryzyka i mitygacje

| Ryzyko | Mitygacja |
|--------|-----------|
| Zbyt duży zakres | Twardy MVP z etapów; poza zakresem tylko po teście frajdy |
| Pad nie działa na macOS | DualSense potwierdzony w grze; fallback klawiatura pozostaje dostępny |
| 60 FPS przy wielu wrogach | Reużycie węzłów (object pool), prostsza geometria, bez miękkich cieni |
| Dźwięk nie pasuje do akcji | Warstwy muzyczne zsynchronizowane ze stanem gry, mix mierzony w sesji |
| Frustracja > frajda | Codzienne krótkie sesje + telemetria; progi na Etapie 7 |
