# Commodore 64 — PoC techniczny

## Warunek rozpoczęcia

Etap `00-zalozenia-i-bramka.md` jest odblokowany, zaakceptowany i zakończony.

## Cel

Udowodnić na prawdziwym C64, że arena, niezależne celowanie i wystarczająca liczba
przeciwników mogą działać stabilnie w ograniczeniach 64 KB oraz VIC-II.

## Zakres

- Arena wykorzystująca tryb znakowy, bitmapowy lub zatwierdzoną kombinację.
- Gracz, strzał hitscan, kontaktowe obrażenia i podstawowy przeciwnik.
- Prototyp multipleksera sprzętowych sprite'ów i alternatywy znakowej/software sprite.
- Statyczne pule obiektów i tablice struktur zoptymalizowane pod 6510.
- Licznik przekroczeń czasu ramki, obciążenia rastra i wykorzystania pul.
- Test obciążenia określający rzeczywisty limit przeciwników.

## Sterowanie

### Klawiatura i mysz 1351

- Klawiatura: ruch w ośmiu kierunkach.
- Commodore 1351: kierunek celowania względem gracza.
- Przycisk myszy: ciągły ogień.

### Joystick i klawiatura

- Joystick: ruch gracza.
- Klawiatura: osiem kierunków celowania i strzał.
- Skanowanie klawiatury nie może powodować konfliktu z wybranym portem joysticka.

## Decyzje po PoC

- Tryb VIC-II i organizacja areny.
- Sprzętowe sprite'y z multiplekserem, obiekty znakowe albo model hybrydowy.
- Częstotliwość logiki, renderowania oraz próbkowania wejścia.
- Maksymalna liczba przeciwników i efektów.
- Ostateczny układ klawiszy i port urządzeń.
- Funkcje wymagające implementacji w asemblerze.

## Kryteria zakończenia

- [ ] Arena, ruch, celowanie, strzał, trafienie i obrażenia działają.
- [ ] Mysz 1351 + klawiatura działają na prawdziwym C64.
- [ ] Joystick + klawiatura działają bez konfliktów CIA.
- [ ] Wejście pozostaje responsywne przy maksymalnym obciążeniu PoC.
- [ ] Nie występują widoczne błędy multipleksera ani uszkodzenia pamięci.
- [ ] Ustalono i zaakceptowano limit przeciwników oraz model renderowania.
- [ ] PoC działa z D64 w VICE i na prawdziwym C64 PAL.
- [ ] Drzewa macOS i Amigi nie zostały zmienione.
