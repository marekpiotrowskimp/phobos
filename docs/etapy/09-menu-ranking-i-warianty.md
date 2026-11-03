# Etap 9 — Menu, ranking i warianty

## Cel

Rozszerzyć grywalne MVP o lokalną rywalizację, wybór poziomu trudności oraz wizualne
urozmaicenie przeciwników bez dodawania nowych mechanik walki.

## 9.1 — Menu i trudność

Menu główne zawiera: `GRAJ`, `TRUDNOŚĆ`, `WYNIKI`, `WYJŚCIE`.

| Poziom | Leczenie | Overdrive | Pity leczenia |
|---|---:|---:|---:|
| Łatwy | 14% | 9% | 6 zabójstw |
| Normalny | 8% | 5% | 10 zabójstw |
| Trudny | 4% | 2% | 14 zabójstw |

- Trudność wpływa wyłącznie na częstotliwość dropów.
- Brak mnożnika punktów.
- Wybrany poziom jest zapamiętywany i pozostaje stały przez całą rundę.
- Restart uruchamia kolejną rundę na tej samej trudności.

## 9.2 — Lokalny ranking

- Top 10 przechowywane osobno dla każdego poziomu trudności.
- Jeden ekran wyników z filtrem: Wszystkie, Łatwy, Normalny, Trudny.
- Wpisywanie trzech inicjałów klawiaturą lub padem po wyniku kwalifikującym się do Top 10.
- Rekord: inicjały, wynik, trudność, fala, zabicia, czas przetrwania i data.
- Zapis w `user://phobos.cfg` z migracją istniejącego pojedynczego rekordu do `OLD / Normalny`.
- Sortowanie: wynik, fala, zabicia i czas malejąco; starszy rekord wygrywa pełny remis.

## 9.3 — Warianty skorpionów

| Wariant | Udział spawnów | Punkty bazowe |
|---|---:|---:|
| Czerwony | 70% | 10 × fala |
| Bursztynowy | 22% | 25 × fala |
| Fioletowy | 8% | 50 × fala |

- Warianty mają identyczne HP, szybkość, obrażenia i hitbox.
- Kolor, oznaczenie pancerza i punktacja są jedynymi różnicami.
- Punktacja nie zależy od wybranego poziomu trudności.

## 9.4 — Walidacja

- Test zapisu, migracji, sortowania, filtrowania i limitu Top 10.
- Test inicjałów A–Z oraz sterowania klawiaturą i padem.
- Test rozkładu dropów na 10 000 losowań dla każdego poziomu.
- Test rozkładu wariantów i poprawnej punktacji.
- Autotest, stress test 60 przeciwników oraz build universal macOS.

## Kryteria zakończenia

- [x] Z menu można rozpocząć grę, zmienić trudność, otworzyć wyniki i wyjść.
- [x] Trudność zmienia wyłącznie dropy i jest widoczna podczas rundy oraz w rankingu.
- [x] Wynik kwalifikujący pozwala wpisać trzy inicjały padem i klawiaturą.
- [x] Ranking zachowuje maksymalnie 10 wyników na trudność i poprawnie filtruje widok.
- [x] Stary rekord zostaje zachowany po migracji.
- [x] Trzy kolory skorpionów mają prawidłowe udziały i punktację.
- [x] Autotest, stress test i finalny build przechodzą bez regresji.
