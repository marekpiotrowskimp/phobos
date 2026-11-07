# App Store Connect — lista kontrolna PHOBOS (iOS / iPadOS)

Wypełnia użytkownik w [App Store Connect](https://appstoreconnect.apple.com). Agent przygotował
gotowe odpowiedzi. Kolejność odpowiada ekranom ASC. Pola tekstowe sklepu są w
`metadata-pl.md` i `metadata-en.md`, a zrzuty ekranu w `screenshots.md`.

## App Information

- [ ] **My Apps → + → New App**
  - Platforms: iOS
  - Name: **PHOBOS Survivor** (zarezerwowana w App Store Connect)
  - Primary Language: Polish (dodaj też lokalizację English (U.S.))
  - Bundle ID: **com.marek.piotrowski.phobos**
  - SKU: `phobos-ios`
  - User Access: Full Access
- [ ] Category: Primary **Games → Action**, Secondary **Games → Arcade**
- [ ] Content Rights: „Does your app contain, show, or access third-party content?” → **No**.
  Fonty (OFL) i silnik Godot (MIT) są osadzone na licencjach otwartych, a pełne teksty są na
  ekranie LICENCJE w grze. Grafika jest własna, wygenerowana przez AI (Claude).
- [ ] Nazwa pod ikoną na telefonie pozostaje „PHOBOS” (`CFBundleDisplayName`).

## Pricing and Availability

- [ ] Price: **Free** (Tier 0 / 0,00 zł). Umowa Paid Apps nie jest potrzebna.
- [ ] Availability: wszystkie kraje i regiony (albo wybrane).
- [ ] In-App Purchases / Subscriptions: brak.

## App Privacy

- [ ] Privacy Policy URL: patrz sekcja **URLs**.
- [ ] „Do you or your third-party partners collect data from this app?” → **No, we do not
  collect data from this app**. Etykieta w sklepie: **Data Not Collected**.
- [ ] Zgodne z `PrivacyInfo.xcprivacy` w buildzie: brak śledzenia (NSPrivacyTracking = false),
  brak zbieranych danych, zadeklarowane tylko „required reason API” silnika.

## Age Rating

Kwestionariusz wiekowy (stan 2026). Odpowiedzi proponowane:

| Pytanie | Odpowiedź | Uzasadnienie |
|---|---|---|
| Cartoon or Fantasy Violence | **Frequent/Intense** | całą rundę strzela się do fikcyjnych obcych organizmów |
| Realistic Violence | None | brak ludzi i realistycznych zwierząt |
| Prolonged Graphic or Sadistic Realistic Violence | None | — |
| Guns or Other Weapons (jeśli pytanie występuje) | Frequent | futurystyczny karabin egzoszkieletu, nie realistyczna broń |
| Horror/Fear Themes | Infrequent/Mild | mroczna oprawa „bio-industrial horror”, bez straszenia |
| Profanity, Sexual Content, Nudity, Alcohol/Drugs, Gambling, Contests | None | — |
| Medical/Treatment, Mature/Suggestive Themes | None | — |
| Unrestricted Web Access, User-Generated Content, Messaging, Advertising | No | — |
| Loot boxes / In-App Purchases | No | — |

Wynik wylicza ASC; spodziewana kategoria to 9+ albo 13+ zależnie od odpowiedzi o broni.

## Export Compliance

- [ ] Build ma w Info.plist `ITSAppUsesNonExemptEncryption = NO` (false), więc ASC nie pyta
  o szyfrowanie przy każdym buildzie. Gdyby zapytał: „Does your app use encryption?” → **No**
  (tylko szyfrowanie systemowe).

## Digital Services Act

- [ ] Business → Digital Services Act → status: **non-trader** (nie-trader). Gra jest darmowa,
  nie ma zakupów ani reklam i nie jest prowadzona w ramach działalności gospodarczej.
  Adres i telefon nie są wtedy publikowane w sklepie UE.

## Game Controllers

- [ ] Build deklaruje w Info.plist `GCSupportsControllerUserInteraction = true` i profil
  `ExtendedGamepad`, więc App Store może pokazać, że gra obsługuje kontrolery.
- [ ] **Nie zaznaczaj „Game Controller Required”.** Gra jest w pełni grywalna dotykiem
  (wymóg Apple dla iOS).

## Version Information

- [ ] Wersja 0.1.0 (numer buildu rośnie przy każdej wysyłce — etap 05).
- [ ] Teksty: `metadata-pl.md` (Polish) i `metadata-en.md` (English (U.S.)).
- [ ] Zrzuty ekranu: `screenshots.md`.
- [ ] Copyright: `2026 Marek Piotrowski`
- [ ] Ikona 1024×1024 jest w buildzie, więc nie trzeba jej wysyłać osobno.
- [ ] Sign-In Information: **Sign-in required → No** (brak kont).
- [ ] Notes for review: patrz etap 05 (`review-notes.md`).

## URLs

Strony HTML (EN + PL) są w `docs/` i są publikowane przez GitHub Pages z gałęzi `main`, katalog `/docs`
(Settings → Pages → Deploy from a branch → `main` / `/docs`). Zaczną działać po scaleniu `port/ios` do `main`.
Przed wpisaniem sprawdź, czy otwierają się w przeglądarce bez logowania.

- Support URL: https://marekpiotrowskimp.github.io/phobos/support.html (PL: `support_pl.html`)
- Privacy Policy URL: https://marekpiotrowskimp.github.io/phobos/privacy_policy.html (PL: `privacy_policy_pl.html`)
- Marketing URL (opcjonalnie): https://marekpiotrowskimp.github.io/phobos/support.html
