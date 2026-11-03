# Etap 5 — Game feel i audio

## Cel

Frajda ze strzelania: feedback wizualny, rumble i dźwięk działające razem z mechaniką. Muzyka warstwowa, która narasta z falami i sygnalizuje zagrożenie bez patrzenia na ekran.

## Zakres wizualny

- Gracz: sprite 512×512, grafitowy egzoszkielet, cyjanowy wizjer, czytelny kierunek broni; 4 klatki ruchu.
- Wróg: sprite skorpiona 512×512, krwisty pancerz, szczypce, segmentowany ogon i świecące żądło; 4 klatki pełzania.
- Pickupy: nanokapsuła leczenia i reaktor Overdrive, każdy z własną sylwetką i animacją pulsu.
- Arena: metalowe panele, przewody, ślady krwi, narośla biologiczne, światła alarmowe i telegraph spawnu.
- Sprite'y są wyświetlane na płaszczyźnie XZ jako `AnimatedSprite3D`; kolizje i logika nie zależą od grafiki.
- Docelowy rozmiar na ekranie 720p: gracz około 60 px, wróg 45–55 px.
- Muzzle flash (punktowe światło + sprite), tracert zanikający, ślady lotu (trail) przy wrogach w Overdrive.
- Trafienie: iskry + krótki biały flash na wrogu; śmierć: eksplozja cząstek.
- Odrzut kamery (recoil kick) przy strzale; mikro-screen-shake przy zniszczeniu.
- Tło areny reaguje na falę (kolor strobujący przy wysokiej intensywności).
- Vignette zdrowia: czerwony puls < 30 hp.
- Rumble: lekki przy strzale, mocny przy trafieniu gracza, wzmocniony w Overdrive.

## Zakres audio

- SFX proceduralne (AudioStreamGenerator): strzał, trafienie, śmierć wroga, obrażenia, pickup, overdrive start/stop, nowa fala, game over.
- **Muzyka warstwowa (dark synth, proceduralna):** warstwy (pad, bas, rytm, lead) przełączane stanem:
  - spokój (start fali początkowej / przerwa),
  - narastanie (fala n, im dalej tym gęściej),
  - wysoka intensywność (Overdrive / fala ≥ 8),
  - przerwa po fali (oddech ~6 s).
- Zdarzenia dźwiękowe „otoczenia": gdy fala ≥ 5, sygnał ostrzegawczy przed spawnem fali (słychać „że coś nadciąga").
- Mix: SFX nad muzyką, ducking muzyki przy niskim HP.

## Rezultat dla gracza

Czuje i słyszy każdy strzał i trafienie; słyszy nadciągającą falę; muzyka trzyma napięcie, a przy Overdrive gra „na pełnej".

## Kryteria akceptacji

- [x] Każdy strzał ma: flash, tracert, dźwięk, rumble (mierzalne w sesji).
- [x] W gameplayu nie są widoczne zastępcze kapsuły, kule ani „kolorowe kropki".
- [x] Gracz, wróg, leczenie i Overdrive są rozpoznawalne bez patrzenia na HUD.
- [x] Zmiana fali zmienia warstwę muzyki w < 0.5 s.
- [x] Sygnał nadciągającej fali jest słyszalny co najmniej 3 s przed spawnem.
- [x] Brak słyszalnych przesterowań przy docelowej presji.
- [x] Wyciszenie działa (klawisz M / opcja) i pauza (Esc).

## Testowanie

- Sesja z zamkniętymi oczami: czy słychać strzał, trafienie, falę, Overdrive?
- Pomiar maks. liczby jednoczesnych dźwięków (AudioServer.get_bus_mix) przy 30 wrogach.

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Muzyka przytłacza SFX | Ducking + limiter; osobne busy |
| Zbyt dużo dźwięków = szum | Polifonia limitowana, pool AudioStreamPlayer |
| Proceduralny audio „śmieci" | Proste fale + szum + filtr; test porównawczy z nagraniami |
