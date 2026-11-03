# Amiga 500 — PoC techniczny

## Warunek rozpoczęcia

Etap `00-zalozenia-i-budzet.md` jest zaakceptowany i zakończony.

## Cel

Udowodnić na prawdziwej A500, że podstawowa walka, oba tryby sterowania i zakładana
liczba obiektów mieszczą się w budżecie sprzętu.

## Status

`IMPLEMENTED` — build i deterministyczny test logiki przechodzą. Test ergonomii obu trybów
na prawdziwej A500 został przeniesiony do końcowej walidacji Etapu 05.

## Zakres

- Pełnoekranowa arena 4:3 z granicami kolizji.
- Gracz z ruchem, celowaniem 360° i ciągłym strzałem hitscan.
- Jeden typ przeciwnika: spawn z krawędzi, pościg, trafienie i kontaktowe obrażenia.
- Statyczne pule gracza, przeciwników i efektów.
- Licznik czasu ramki, maksymalnego obciążenia i wykorzystania pul.
- Test obciążenia zwiększający liczbę przeciwników do momentu przekroczenia budżetu.

## Sterowanie

### Klawiatura i mysz

- Klawiatura: ruch w ośmiu kierunkach.
- Mysz: kierunek celowania względem pozycji gracza.
- Przycisk myszy: ciągły ogień.

### Joystick i klawiatura

- Joystick: ruch gracza.
- Klawiatura: kursory do celowania, spacja do ciągłego ognia.
- Port joysticka obsługuje ruch; spacja pozostaje ogniem, ponieważ linia fire z CIAA nie jest
  wiarygodna w konfiguracji emulatora.

## Decyzje po PoC

- 50 FPS albo logika 50 Hz z renderowaniem 25 FPS.
- Maksymalna liczba aktywnych przeciwników.
- Liczba jednoczesnych efektów i częstotliwość strzału możliwa bez utraty wejścia.
- Podwójny bufor, pojedynczy bufor z odświeżaniem fragmentów albo inny zaakceptowany model.
- Ostateczny układ klawiszy obu trybów.

## Kryteria zakończenia

- [x] Arena, ruch, celowanie, strzał, trafienie i obrażenia działają.
- [ ] Oba tryby sterowania są grywalne na prawdziwej A500.
- [x] Wejście jest próbkowane w każdej ramce PAL przy 16 aktywnych przeciwnikach.
- [x] Statyczne pule i test headless nie wykazują uszkodzeń pamięci ani przekroczeń tablic.
- [x] Przyjęto logikę 50 Hz, renderowanie 50 FPS i limit 16 aktywnych przeciwników.
- [x] PoC jest zbudowany jako bootowalny ADF i przechodzi test CPU 68000 w `vamos`.
- [x] Drzewo `project/` nie zostało zmienione.

## Implementacja

- `src/game.c` — logika rundy portowana 1:1 z `main.gd`, `player.gd`, `enemy.gd`, `pickup.gd`
  i `balance.gd`: jednostki świata Godot w Q10 (40×24 j.), krok 50 Hz, kąty 0..1023,
  ruch z bezwładnością (11 j/s, accel 12), płynne celowanie 360°, hitscan z promieniem
  trafienia 0,72 j. i zatrzymaniem na ścianie, kontakt 1,15 j., niewrażliwość 0,55 s.
- `src/hw.c` — przejęcie ekranu własnymi listami Coppera (LoadView + serwer VBlank
  przełączający listę w wygaszaniu), blitter programowany bezpośrednio (cookie-cut, kopie,
  linie), mysz/joystick z rejestrów, klawiatura przez IDCMP. System pozostaje aktywny,
  więc zapis rankingu działa przez `dos.library`.
- `src/render.c` — ekran podzielony Copperem: górny HUD (30 linii), arena 320×200
  (8 px = 1 j.) z marginesem na wstrząs kamery (BPLCON1 + przesunięcie wskaźników),
  dolny HUD; palety podmieniane w trakcie ramki; gracz jako sprite'y sprzętowe.
- Sterowanie A: `WSAD` + mysz (celownik), lewy przycisk lub spacja — ogień.
- Sterowanie B: joystick w porcie 2 (ruch, fire) + kursory: celowanie z ciągłym ogniem.
- `Esc` — pauza jak w oryginale; wyjście do AmigaDOS przez `WYJŚCIE` w menu.
