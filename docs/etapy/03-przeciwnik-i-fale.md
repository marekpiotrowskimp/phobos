# Etap 3 — Przeciwnik i fale

## Cel

Jeden typ wroga napływający z krawędzi areny, goniący gracza, atakujący kontaktowo, oraz system fal o rosnącej trudności.

## Zakres

- Wróg: bio-mechaniczny skorpion z dużymi szczypcami, ośmioma odnóżami, segmentowanym ogonem i świecącym żądłem; obrażenia kontaktowe.
- Spawn: na losowej krawędzi areny, poza kadrem/na obrzeżu, minimalny dystans od gracza (bez spawn-in-face).
- Fala jest sterowana czasowo: `35 + 5 × (n - 1)` sekund, maksymalnie 65 s.
- Director utrzymuje docelową liczbę aktywnych wrogów: `min(8 + 3 × (n - 1), 45)`.
- Spawn odbywa się grupami po 2–5 wrogów z kilku krawędzi; grupy mają czytelny telegraph na podłodze.
- Po zakończeniu czasu director przestaje spawnować, a fala kończy się po zabiciu pozostałych wrogów.
- Przerwa między falami wynosi około 5 s i pozostaje muzycznym „oddechem".
- Wróg ginie od 1 strzału (MVP: czystość zamiast HP).
- Śmierć: eksplozja cząstek + dźwięk; licznik zabójstw.
- Pula obiektów dla maksymalnie 60 wrogów i tracertów — brak alokacji w pętli.
- Powiadomienie o nowej fali: banner „FALA n" + zmiana koloru areny.

## Rezultat dla gracza

Czuje osaczenie: wrogowie nadciągają ze wszystkich stron, każda fala gęstsza i szybsza, a on zarządza kątami ognia.

## Kryteria akceptacji

- [x] Wróg napływa z krawędzi i goni gracza.
- [x] Kontakt wroga zadaje obrażenia.
- [x] Pierwsza fala trwa co najmniej 35 s i utrzymuje zauważalną presję.
- [x] Fale 1–5 dają czytelny wzrost trudności; około fali 5 aktywnych jest co najmniej 20 wrogów.
- [x] Director nigdy nie przekracza limitu 45 aktywnych ani puli 60 obiektów.
- [x] Nie ma spawnu tuż obok gracza.
- [x] Banner fali widoczny i nie blokuje akcji.

## Testowanie

- Skryptowana fala 5, 10 i 20 w trybie debug — pomiar FPS i liczby żywych wrogów.
- Subiektywna ocena: „czy czuję presję?" przy fali 5 vs 10.

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Chaos > czytelność przy >30 wrogach | Test z pułapem 60; jeśli nieczytelnie → limit 40 + wolniejsze spawn |
| Spawn-in-face | Min. dystans spawnu od gracza, spawn tylko z krawędzi |

## Poza zakresem

Różne typy wrogów, HP wrogów, boss, dropy.
