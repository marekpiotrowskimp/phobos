# Etap 7 — Test frajdy i decyzja

## Cel

Ocenić, czy po tygodniu gra się **uruchamia dla przyjemności**, i podjąć decyzję GO / ITERATE / STOP na podstawie twardych danych, nie wrażeń z jednego wieczoru.

## Metoda: dziennik sesji (codziennie, 15 min)

Każdego dnia: jedna sesja na buildzie (nie w edytorze), zapis w `docs/dziennik-sesji.md`:

| Pole | Opis |
|------|------|
| Data / fala max / czas przetrwania | liczby |
| „Czy chciałem zagrać jeszcze raz?" | TAK / NIE + powód |
| Największa frajda | konkretny moment |
| Największa frustracja | konkretny moment |
| Propozycja 1 zmiany | jedna, najmniejsza |

## Kryteria decyzyjne

**GO** — gdy w ≥ 3 z 7 sesji: „TAK, gram dalej po zakończeniu sesji", a frustracja < 25% wpisów i ma znaną przyczynę.

**ITERATE** — gdy frajda jest blisko, ale: frustracja ≥ 25%, albo powtarzające się przyczyny „nie chcę grać", albo krytyczne błędy. Wtedy: spis konkretnych poprawek, 1–2 dni iteracji, ponowny test.

**STOP** — gdy po ≥ 3 iteracjach nie ma frajdy lub zanika motywacja. Projekt nie ma sensu — kończymy bez żalu i bez „sunk cost".

## Po GO

- Ustalenie zakresu kolejnej iteracji: boss, druga broń, druga arena lub progresja.
- Kontynuacja w Godot na macOS; port PS5 został porzucony.
- Zespół/zasoby, harmonogram, budżet.

## Status

- [x] Użytkownik potwierdził, że testy manualne oraz aktualny stan gry są satysfakcjonujące.
- [x] Problemy wskazane w dwóch udokumentowanych sesjach zostały poprawione i ponownie zweryfikowane.
- [x] Decyzja: **GO** — projekt pozostaje rozwijany w Godot z platformą docelową macOS.

Pełny protokół siedmiu wpisów zakończono decyzją właściciela projektu po dwóch udokumentowanych
sesjach i dodatkowych testach manualnych. Brakujące sesje nie zostały dopisane retrospektywnie.

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Test sam ze sobą = stronniczy | Dziennik + liczby; zaprosić 1–2 osoby do sesji |
| „Jeszcze jedna runda" przez przypadek, nie frajdę | Pytanie „czy chciałem zagrać?" po 10 min przerwy |
| Decyzja pod wpływem złego dnia | Minimum 3 sesje z danymi przed decyzją |
