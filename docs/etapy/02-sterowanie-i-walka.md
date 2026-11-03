# Etap 2 — Sterowanie i walka

## Cel

Gracz sterowany gałkami: ruch niezależny od celowania, broń automatyczna typu hitscan z widocznym tracertem i poczuciem siły ognia.

## Zakres

- Ruch: lewa gałka → prędkość z przyspieszeniem i tarciem; nie zmienia kierunku celowania.
- Celowanie: prawa gałka → wektor celu; postać obraca się w kierunku strzału.
- Martwe strefy gałek: centralna (ruch) i przedwzmacniacz (aim) — regulowane w export vars.
- Broń: automatyczny karabin, hitscan (RayCast zamiast pocisku), ~10 strz./s.
- Wizualizacja: tracert (linia zanikająca), muzzle flash, delikatny odrzut kamery, dźwięk strzału.
- Pocisk trafia w ścianę areny lub wroga (wróg w Etapie 3) — na razie w ściany.
- Kolizje: CharacterBody2D gracza + statyczne ściany areny (bez wyjścia poza arenę).

## Rezultat dla gracza

Sterowanie „śledzi myśli”: biegniesz w jedną stronę, strzelasz w drugą, strzał czuć i słychać.

## Kryteria akceptacji

- [x] Ruch i celowanie działają niezależnie (obie gałki jednocześnie).
- [x] Strzał ciągły przy trzymanym R2; ~10 strz./s bez spadku FPS.
- [x] Tracert widoczny i zanikający; muzzle flash czytelny.
- [x] Gracz nie opuszcza areny; kolizja ze ścianami płynna.
- [x] Odrzut kamery nie rozjeżdża się z celowaniem (płynne, małe).

## Testowanie

- Ruch obiema gałkami w przeciwne strony (taniec).
- Pomiar FPS podczas ciągłego ognia.
- Dźwięk i flash oceniane subiektywnie (skala 1–5 w sesji).

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Strzał czuć jako „tacker", nie broń | Layering: flash + tracert + rumble + dźwięk, iteracja parametrów |
| Deadzone gałki celuje „po ekranie" | Przedwzmacniacz wejścia, krzywa nieliniowa, test z DualSense |

## Poza zakresem

Wrogowie, obrażenia, dropy, HUD, muzyka.
