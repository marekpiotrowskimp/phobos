# Etap 6 — Balans i build macOS

## Cel

Dopracować pierwsze 10–15 minut rozgrywki, potwierdzić stabilność przy maksymalnym natężeniu i dostarczyć gotowy build `.app`.

## Zakres

- Balans krzywej trudności na podstawie sesji z Etapu 7 (dziennik):
  - czas do śmierci przeciętnego gracza: fala 3–5 w 3 min, fala 8+ w 8–10 min,
  - dropy: pokrycie ~65–80% czasu walki leczeniem/overdrive,
  - DPS wroga vs tempo dropów — bez „ściany" i bez nudy.
- Regulowane parametry w autoloadzie `Balance` (export vars) — bez rekompilacji na iterację.
- Optymalizacja: profiler pod max load (fala 20, 60 wrogów) — FPS ≥ 60.
- Cel presji po pierwszym playteście: fala 1 trwa ≥ 35 s, a typowa pierwsza śmierć następuje na fali 4–6 po 3–5 min.
- Test DualSense: przyciski, gałki, rumble, tryb Bluetooth i USB.
- Eksport: Preset macOS (arm64, później universal), ikona, nazwa `PHOBOS`, `xattr -dr com.apple.quarantine` + ad-hoc codesign, test z Docka.
- README w buildzie: jak uruchomić (Gatekeeper), sterowanie.

## Rezultat dla gracza

Gra działa stabilnie 60 FPS, trudność „wciąga" zamiast frustrować, a build odpala się bez terminala i wiedzy technicznej.

## Kryteria akceptacji

- [x] 3 kolejne rundy ≥ 8 fali bez glitchy i spadków FPS (60±).
- [x] W rundach testowych typowa śmierć występuje na fali 4–6; przeżycie nie jest gwarantowane przez dropy.
- [x] 45 aktywnych wrogów, animowane sprite'y i ciągły ogień utrzymują 60 FPS (finalny stress: 60 wrogów, min. 115,4 FPS).
- [x] DualSense działa na macOS: ruch, celowanie, strzał, menu, pauza i rumble.
- [ ] Połączenie DualSense zostało zweryfikowane osobno przez Bluetooth i USB.
- [x] Build `.app` uruchamia się z Docka/Findera (Gatekeeper obsłużony).
- [ ] Wszystkie parametry balansu w jednym pliku `Balance`.

## Testowanie

- 3 sesje po 15 min na buildzie (dziennik z Etapu 7).
- Profiler pod fala 20 / 60 wrogów / ciągły ogień.
- Test na czystym Macu bez Godota (build nie zależy od silnika).

## Ryzyka

| Ryzyko | Mitygacja |
|--------|-----------|
| Gatekeeper blokuje build | xattr + ad-hoc codesign, instrukcja w README |
| Ciężko balansować „na sucho" | Parametry w pliku, szybkie iteracje, dane z dziennika |
