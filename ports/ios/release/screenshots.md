# Zrzuty ekranu do App Store

Gra działa tylko w poziomie, więc wszystkie zrzuty są **landscape**. App Store Connect wymaga
zestawu dla największego iPhone'a i największego iPada. Mniejsze rozmiary skaluje sam.

| Urządzenie | Rozmiar (px, poziomo) | Przykładowe urządzenie / symulator |
|---|---|---|
| iPhone 6.9" | **2868 × 1320** (akceptowane też 2796 × 1290) | iPhone 17 Pro Max / 16 Pro Max |
| iPad 13" | **2752 × 2064** (akceptowane też 2732 × 2048) | iPad Pro 13" (M4/M5) |

Od 1 do 10 zrzutów na zestaw, PNG lub JPEG, bez przezroczystości.

## Ujęcia (3–5 na urządzenie)

1. Rozgrywka w środku fali: wielu przeciwników, widoczne drążki pod kciukami i strzały.
2. Zbieranie kulki (zielona kapsuła życia lub niebieski reaktor).
3. Menu główne z logo PHOBOS.
4. Ranking TOP 10 z kilkoma wpisami.
5. (opcjonalnie) Późna fala na wyższym poziomie trudności.

Zrzuty mają pokazywać prawdziwą grę (wytyczna 2.3.3): bez ramek z innymi urządzeniami i bez
treści, których nie ma w grze.

## Jak zrobić zrzuty w symulatorze

1. Zbuduj projekt Xcode: `./build.sh ios-xcode` i otwórz
   `ports/ios/project/build/xcode/PHOBOS.xcodeproj`.
2. Wybierz symulator (np. iPhone 17 Pro Max), uruchom (⌘R) i obróć poziomo (⌘→).
3. Zrób zrzut w terminalu:

   ```sh
   xcrun simctl io booted screenshot ~/Desktop/phobos-iphone-1.png
   ```

   albo ⌘S w oknie symulatora. Powtórz dla iPada Pro 13".
4. Sprawdź rozmiar pliku: `sips -g pixelWidth -g pixelHeight ~/Desktop/phobos-iphone-1.png`.

## Na urządzeniu

Przycisk boczny + głośniej. Zrzut z iPhone'a 16/17 Pro Max ma od razu 2868 × 1320 w poziomie.
