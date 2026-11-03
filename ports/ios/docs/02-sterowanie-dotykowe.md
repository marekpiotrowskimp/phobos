# iOS / iPadOS — sterowanie dotykowe

## Warunek rozpoczęcia

Etap 01 ma status `APPROVED`: aplikacja uruchamia się na urządzeniu.

## Cel

Gra ma być w pełni grywalna samym dotykiem, z zachowaniem mechanik z
`docs/porty/01-kontrakt-zgodnosci.md`: niezależnego ruchu i celowania, ciągłego ognia,
pauzy, restartu i wpisywania inicjałów. Pad pozostaje pełnoprawną alternatywą.

## Obecny model wejścia

`ports/ios/project/scripts/autoloads/input_setup.gd` (kopia z `project/`) mapuje akcje na klawiaturę, mysz i pad:

- ruch: `move_*`,
- celowanie: `aim_*`,
- ogień: `shoot`,
- pauza i wyciszenie: `pause`, `mute`,
- menu: `menu_*`.

Warstwa dotyku ma wytwarzać te same akcje, żeby logika w `player.gd`, `main.gd` i `hud.gd`
nie musiała rozróżniać źródła wejścia.

## Rozgrywka: twin-stick dotykowy

| Element | Zachowanie |
|---|---|
| Lewy drążek | Pływający: pojawia się w miejscu pierwszego dotyku w lewej połowie ekranu. Wychylenie analogowe steruje akcjami `move_*`. |
| Prawy drążek | Pływający w prawej połowie. Wychylenie ustawia kierunek `aim_*`. |
| Ogień | Automatyczny przy wychyleniu prawego drążka ponad martwą strefę, zgodnie z kontraktem ciągłego ognia. Puszczenie drążka przerywa ogień. |
| Pauza | Przycisk w rogu ekranu w obrębie safe area. Również automatyczna pauza po zejściu aplikacji do tła. |
| Wyciszenie | Przełącznik w menu pauzy. |
| Restart | Przycisk na ekranie końca rundy. |

Wymagania szczegółowe:

- Multitouch: oba drążki działają jednocześnie, a każdy śledzi swój indeks dotyku.
- Martwa strefa i krzywa odpowiedzi takie same jak dla pada (`deadzone 0.3`), dostrojone
  w testach na urządzeniu.
- Kciuki nie mogą zasłaniać gracza ani strefy spawnu. Drążki są półprzezroczyste i znikają
  po puszczeniu.
- Opcjonalna wibracja Taptic przy trafieniu gracza, odpowiednik rumble na DualSense.

## Menu i ranking

- Elementy menu klikalne dotykiem, cele minimum 44×44 pt.
- Wpisywanie trzech inicjałów:
  - strzałki góra/dół przy każdej literze,
  - albo systemowa klawiatura ograniczona do A–Z.
  Decyzja zapada w tym etapie.
- Filtr trudności w rankingu przełączany dotknięciem.

## Pad

- DualSense, Xbox i MFi przez GameController. Ten sam model akcji co na macOS.
- Po podłączeniu pada nakładka dotykowa znika, a po pierwszym dotyku wraca.
- Gra nigdy nie wymaga pada.

## Bramka akceptacji

- Trzy pełne rundy na iPhonie i trzy na iPadzie samym dotykiem.
- Trzy pełne rundy z DualSense na iPadzie.
- Możliwe jest przetrwanie co najmniej do fali osiąganej na macOS. Brak systematycznej
  przewagi ani straty względem pada zostaje odnotowany w raporcie.
- Ocena „czy chcę zagrać jeszcze raz” wpisana jak w `docs/dziennik-sesji.md`.
- Akceptacja użytkownika.
