# Commodore 64 — pętla gry

## Warunek rozpoczęcia

Oprawa i pipeline zasobów C64 są zaakceptowane.

## Cel

Odtworzyć pełną rundę PHOBOS z presją i czytelnością dostosowaną do limitów C64.

## Zakres

- Director fal, telegraph, spawn z krawędzi i przerwy między falami.
- Czerwony, bursztynowy i fioletowy wariant przeciwnika.
- Zdrowie, kontaktowe obrażenia i czas niewrażliwości.
- Leczenie, Overdrive, czas życia pickupów i mechanizm litości.
- Trzy trudności zmieniające wyłącznie częstotliwość dropów.
- Punkty, fala, zabójstwa, czas rundy, game over i restart.
- Pauza, wyciszenie i bezpieczny powrót do menu.

## Adaptacja balansu

Limit aktywnych przeciwników będzie niższy niż w wersji macOS i może być niższy niż na Amidze.
Presję można zachować przez szybkość, wzorzec grup, długość fal i czas przerw. Każda taka zmiana
trafia do macierzy zgodności i wymaga osobnej akceptacji. Relacja punktów wariantów pozostaje
`10 / 25 / 50`, o ile nie zostanie zatwierdzone odstępstwo.

## Testy

- Deterministyczny generator losowy dla testów wariantów i dropów.
- Test pełnego zakresu liczników oraz przepełnień punktacji i czasu.
- Test granic puli przeciwników, efektów i pickupów.
- Test spawnu, Overdrive, pity dropu i czasu niewrażliwości.
- Stress test w najdroższej kombinacji grafiki, SID i logiki.

## Kryteria zakończenia

- [ ] Pełna runda od menu do game over i restartu działa bez przeładowania programu.
- [ ] Wszystkie trzy warianty, oba pickupy i trzy trudności są obecne.
- [ ] Presja rośnie bez nieczytelnego lub losowo niesprawiedliwego skoku.
- [ ] Liczniki nie przepełniają się podczas zakładanego maksymalnego czasu gry.
- [ ] Najgorsze obciążenie mieści się w zatwierdzonym budżecie PAL.
- [ ] Odstępstwa od macOS i Amigi są zapisane oraz zaakceptowane.
- [ ] Trzy pełne rundy przechodzą w VICE i na prawdziwym C64.
- [ ] Drzewa pozostałych platform nie zostały zmienione.
