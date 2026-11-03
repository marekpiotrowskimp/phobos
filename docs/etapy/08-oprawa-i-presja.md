# Etap 8 — Oprawa i presja

## Cel

Zastąpić zastępcze bryły pełnoprawną oprawą bio-industrial horror oraz przebudować fale tak,
aby gra utrzymywała presję i dawała realną możliwość przegranej.

## Zasada realizacji

Każdy podetap wymaga osobnej zgody użytkownika. Po ukończeniu podetapu prezentowany jest rezultat
i wyniki testów. Następny podetap nie rozpoczyna się automatycznie.

## Podetap 8.1 — Koncepty sprite'ów

- Statyczny sprite gracza i bio-mechanicznego skorpiona w rzucie z góry.
- Format SVG 512×512, przezroczyste tło, wysoka czytelność przy rozmiarze 45–60 px.
- Test sylwetki na jasnym i ciemnym tle oraz w docelowej kamerze gry.
- Bramka: akceptacja wyglądu obu postaci przed tworzeniem animacji.

## Podetap 8.2 — Animacje i integracja postaci

- Cztery klatki ruchu gracza i cztery klatki pełzania skorpiona.
- Integracja jako `AnimatedSprite3D` na płaszczyźnie XZ.
- Zachowanie istniejących kolizji, celowania, flasha trafienia i efektu spawnu.
- Usunięcie widocznych kapsuł i kul zastępczych.

## Podetap 8.3 — Pickupy i arena

- Sprite nanokapsuły leczenia i reaktora Overdrive.
- Metalowe panele podłogi, przewody, ślady krwi i biologiczne narośla.
- Telegraph grupowego spawnu oraz osobne cienie i poświaty postaci.
- Kontrola czytelności walki przy minimum 20 aktywnych wrogach.

## Podetap 8.4 — Wave director

- Fale czasowe 35–65 s zamiast stałej małej kolejki.
- Docelowa liczba aktywnych: 8 na fali 1, następnie +3 na falę, limit 45.
- Spawn grupami po 2–5 przeciwników i zatrzymanie spawnu po upływie czasu fali.
- Koniec fali dopiero po usunięciu pozostałych przeciwników.
- Wszystkie parametry pozostają w `Balance`.

## Podetap 8.5 — Balans zagrożenia i dropów

- Obrażenia kontaktowe 18 hp i nietykalność 0,55 s jako wartości startowe.
- Leczenie +30 hp z szansą 8%; Overdrive z szansą 5%.
- System litości przy niskim hp po 10 zabójstwach bez leczenia.
- Cel: typowa pierwsza śmierć na fali 4–6 po 3–5 min.

## Podetap 8.6 — Walidacja i build

- Trzy pełne rundy z zapisem czasu, fali, liczby zabójstw i przyczyny śmierci.
- Profilowanie przy 45 aktywnych oraz test puli 60 przeciwników.
- Ręczny test DualSense, pauzy, restartu, dropów i czytelności sprite'ów.
- Autotest, eksport universal macOS i test uruchomienia `.app`.

## Poprawka 8.6a — Czytelność dzienna

- Jasność skorpionów ma minimalny poziom niezależny od oświetlenia areny.
- Arena pozostaje ciemna; korekta nie rozjaśnia podłogi, HUD ani efektów.
- Wymagany ręczny test w ciemnym pomieszczeniu oraz w dzień przy świetle padającym na ekran.

## Kryteria zakończenia

- [x] Brak widocznych zastępczych brył postaci i pickupów.
- [x] Wszystkie obiekty gameplayowe są rozpoznawalne bez HUD w dzień i w ciemnym pomieszczeniu.
- [x] Pierwsza fala trwa minimum 35 s i nie ma pustych okresów walki.
- [x] Gracz ma realną szansę zginąć bez sztucznego skoku trudności.
- [x] Gra utrzymuje 60 FPS przy docelowej presji.
- [x] Każdy podetap został osobno zaakceptowany przed rozpoczęciem.

## Wyniki walidacji automatycznej

- Autotest finalnego builda: fala 1 trwa 36,2 s; peak 8; fala 2 utrzymuje cel 11; 146 zabójstw, 10 dropów leczenia i 6 dropów Overdrive.
- Testy obrażeń 18 hp, i-frame 0,55 s, śmierci, szans 8%/5%, resetu pity oraz zachowania przy pełnej puli przechodzą.
- Stress test finalnego `.app` po poprawce 8.6a, Metal / Apple M4 Pro / 1280×720: pełna pula 60 skorpionów, minimum 111,8 FPS, średnio 115,0 FPS, minimum 59 aktywnych podczas ciągłego ognia.
- Build `project/build/PHOBOS.app`: podpis poprawny, universal `x86_64 + arm64`, Retina aktywna.

## Status

Etap 8 jest zakończony. Użytkownik potwierdził ręcznie:

- czytelność skorpionów i dropów w dzień oraz w ciemnym pomieszczeniu,
- płynne narastanie presji i realną możliwość śmierci,
- poprawne działanie pełnej pętli gry,
- działanie DualSense na macOS, w tym ruchu, celowania, R2 i rumble.
