# Etap 4 — Pickupy, HUD i pętla gry

## Cel

Pełna pętla gry: zdrowie, punkty, fale, dropy, przegrana i szybki restart. Gracz ma zawsze jasny stan (hp, wynik, fala) i cel (przetrwać, ulepszać się).

## Zakres

- **Gracz:** hp 100, regeneracja minimalna tylko z dropów; obrażenia kontaktowe; krótka nieśmiertelność po trafieniu (blink, 0.7 s).
- **Punkty:** za zabójstwo (10 × fala) + premia za przeżycie fali (50 × fala).
- **HUD:**
  - pasek zdrowia (lewy dół, animowany spadek),
  - licznik punktów (góra),
  - numer fali (góra, przy bannerze),
  - licznik zabójstw.
- **Dropy z wrogów:**
  - leczenie (+30 hp, 8% szans bazowych),
  - *Overdrive* (15 s: x2 dmg, x1.5 fire rate, niebieski glow na arenie, 5% szans bazowych),
  - system litości: przy hp ≤ 50 wymusza leczenie po 10 zabójstwach bez dropu leczniczego,
  - dropy znikają po ~8 s, pulsują i mają czytelny kolor.
- **Game Over:** ekran z wynikiem, najlepszym wynikiem (zapis ConfigFile), czasem przetrwania i przyciskiem „Jeszcze raz".
- **Restart:** < 3 s od śmierci do pierwszej fali.

## Rezultat dla gracza

Wie, co robić, co zbierać, kiedy umiera; chce „jeszcze jedną rundę", bo wynik jest mierzalny i rytm rundy jest krótki.

## Kryteria akceptacji

- [x] HUD aktualizuje się natychmiast (hp/punkty/fala).
- [x] Dropy spadają z zadanym prawdopodobieństwem i działają poprawnie (leczenie/overdrive).
- [x] Leczenie nie pozwala utrzymywać pełnego hp bez przerw, ale system litości zapobiega losowo niesprawiedliwej śmierci.
- [x] Overdrive czytelny (kolor/glow na ekranie) i mierzalnie wzmacnia ogień.
- [x] Śmierć → ekran wyniku → restart pełnej rundy w < 3 s.
- [x] Najlepszy wynik zapisuje się między sesjami.

## Testowanie

- 10 symulowanych fal z autostrzelaniem (debug) — sprawdzenie wartości statystyk.
- Ręczny test: celowe branie obrażeń, zbieranie dropów, śmierć i restart x5.

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Overdrive zbyt mocny/słaby | Parametry w autoloadzie balansu, szybka iteracja |
| Ekran końca zbyt długi | Restart na Enter/pad A natychmiast, animacja < 0.5 s |

## Poza zakresem

Zapisywanie profilu, statystyki kariery, achievements.
