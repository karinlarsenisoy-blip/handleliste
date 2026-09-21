# Handleliste — spesifikasjon

Norsk handleliste-app med prissammenligning: crowdsourcet, kvitteringsbasert prisdatabase på tvers av kjeder, "hvor er dette billigst akkurat nå", en butikk-eller-splitt handletur-planlegger, og en foreslått ruterekkefølge basert på butikkens faktiske avdelingslayout.

## Teknologistack

| Del | Valg |
|---|---|
| UI-rammeverk | Flutter (Dart), Material 3, kjører i dag som web-app |
| Autentisering | Firebase Authentication — anonym (gjest, automatisk) + e-post/passord + Google |
| Database | Cloud Firestore |
| Server-side | Én Cloud Function (`functions/nearbyStores`) — proxy mot Overpass/OpenStreetMap |
| Tredjeparts prisdata | Kassalapp (kassal.app) — dekker Coop/Spar/Meny/Joker/Oda, ikke Kiwi/Rema 1000 |
| Tredjeparts produktdata | Open Food Facts — reserveløsning når Kassalapp mangler nøkkel/feiler |
| Firebase-prosjekt | `handleliste-f1659` |
| Testing | `flutter_test` + `fake_cloud_firestore` (ingen ekte Firebase-tilkobling i tester) |

## Mappestruktur

```
lib/
  main.dart                        Starter Firebase, viser AuthGate
  firebase_options.dart            Autogenerert av FlutterFire CLI — prosjektnøkler (ikke hemmelig)
  config/
    market.dart                    currentMarket ('no' i dag) — forberedelse for flere land
  models/
    item.dart, shopping_list.dart  Vare / liste
    receipt.dart, receipt_item.dart Kvittering / kvitteringslinje
    price_observation.dart         Én rå prisobservasjon (append-only, anonym)
    current_price.dart             Denormalisert "siste kjente pris"-rad
    product_suggestion.dart        Ett Kassalapp/Open Food Facts-treff
    store.dart                     Kjente kjeder per marked + gjenkjenning
    store_location.dart            Én fysisk butikkfilial (fra OpenStreetMap)
    store_layout.dart              Crowdsourcet avdelingsrekkefølge for én filial
    store_total.dart, shopping_split.dart, cheapest_store_analysis.dart
                                    Resultatene av CheapestStoreService.analyze()
    favorite_item.dart             Én rad i favoritt-rangeringen
  services/
    item_service.dart, list_service.dart, account_service.dart
                                    CRUD for lister/varer + GDPR-sletting
    receipt_service.dart           Lagring av kvitteringer + duplikat-sjekk
    receipt_parser.dart            Tekst → varelinjer (kvitterings-OCR/lim inn)
    ocr_service.dart               On-device tekstgjenkjenning (mobil, ikke web)
    price_service.dart             Den delte, anonyme prisdatabasen
    kassalapp_service.dart         Kassalapp-API-klient
    product_suggestion_service.dart Slår sammen Kassalapp + Open Food Facts, rangert på relevans
    cheapest_store_service.dart    "Billigst akkurat nå" — én butikk / splittet handletur
    favorites_service.dart         Mest kjøpte varer, utledet fra kvitteringshistorikk
    location_service.dart          Enhetens posisjon (Geolocator)
    store_locator_service.dart     Nærmeste fysiske butikker (via Cloud Function-proxyen)
    store_layout_service.dart      Lagrer/henter crowdsourcet butikklayout per filial
  screens/
    auth_gate.dart                 Logger inn anonymt automatisk; SignInScreen kun ved behov
    sign_in_screen.dart            Logg inn / opprett konto (e-post + passord + Google)
    home_shell.dart                Bunnnavigasjon: Hjem / Lister / Kvitteringer / Favoritter
    home_screen.dart               Forsiden: søk, skann kvittering, si varenavn (mikrofon)
    lists_page.dart, list_items_view.dart
                                    Lister og varene i én liste (flat, ingen kategorier)
    cheapest_store_screen.dart     "Én butikk" vs. "Handletur" (splitt) + posisjon/radius
    active_trip_screen.dart        Låst, bekreftet handletur — avkrysning i butikkrekkefølge
    map_store_layout_screen.dart   Kartlegg en butikks avdelingsrekkefølge
    add_receipt_screen.dart        Ny kvittering: kamera+OCR (mobil) eller lim inn (web)
    receipts_page.dart             Kvitteringshistorikk
    favorites_screen.dart          Mest kjøpte varer
    voice_list_entry_screen.dart   "Si varenavn ett og ett" → legg til i en liste
    profile_screen.dart            Konto — ulikt innhold for gjest vs. innlogget bruker
  widgets/
    guest_gate.dart                Delt "opprett konto for å ..."-skjerm for gjestebrukere
    item_tile.dart, item_edit_dialog.dart, product_name_field.dart, list_picker.dart
  utils/
    aisle_order.dart                Gjetter avdeling fra varenavn (ikke fra en kategori)
    relevance_ranking.dart          Rangerer søketreff på hvor godt navnet faktisk matcher
    distance.dart                   Haversine-avstand
    email_typo_checker.dart         "Mente du ...?" på innloggingsskjermen
```

## Arkitektur — hvordan delene henger sammen

```
main.dart
  └─ Firebase.initializeApp()
  └─ HandlelisteApp (MaterialApp)
       └─ AuthGate
            ├─ (ingen bruker ennå)  → logger inn anonymt automatisk, viser spinner
            ├─ (anonym feilet)      → SignInScreen (reserveløsning)
            └─ (innlogget, ev. anonymt) → HomeShell(uid, isAnonymous)
                                            ├─ Hjem        (fritt for alle, også gjester)
                                            ├─ Lister       ┐
                                            ├─ Kvitteringer ├─ krever ekte konto — GuestGateScreen for gjester
                                            └─ Favoritter    ┘
```

- **AuthGate** lytter på `FirebaseAuth.instance.authStateChanges()`. Ingen bruker → `signInAnonymously()` i bakgrunnen, ikke en påtvunget innloggingsskjerm — søk er hele poenget med appen og krever ingen konto.
- **HomeShell** viser fire faner. For en anonym bruker vises `GuestGateScreen` i stedet for Lister/Kvitteringer/Favoritter — disse skriver data knyttet til uid-en, som er verdiløst å bygge opp på en anonym, ikke-gjenopprettbar sesjon.
- **ItemService / ListService / ReceiptService / AccountService** er de eneste stedene som snakker med Firestore for brukerens *egne* data. Items ligger flatt under en liste (`lists/{listId}/items/{itemId}`) — ingen kategori-/mappenivå; hvilken avdeling en vare hører til gjettes fra varenavnet (`aisle_order.dart`), ikke fra en brukerdefinert kategori.
- **PriceService / KassalappService / ProductSuggestionService** kombinerer egen crowdsourcet prisdata (eneste kilde for Kiwi/Rema 1000) med Kassalapps API (Coop/Spar/Meny/Joker/Oda) for søk og prisoppslag.
- **CheapestStoreService.analyze()** henter hvert vare-navns priser én gang og bygger to konsistente visninger fra samme datasett: `storeTotals` (rangering per butikk, dekning før pris) og `split` (matematisk billigste fordeling på tvers av butikker).
- **CheapestStoreScreen** kan i tillegg vise reell avstand til nærmeste filial (`StoreLocatorService`, via Overpass-proxyen) og ekskludere butikker uten kjent filial i nærheten fra splitt-forslaget.
- **ActiveTripScreen** er et låst øyeblikksbilde av en bekreftet rute — endrer seg aldri av seg selv mens noen står i butikken, selv om posisjon/radius ville gitt et annet forslag nå.

## Datamodell (Firestore)

```
users/{uid}/lists/{listId}
  name: string, order: number, createdAt: timestamp

users/{uid}/lists/{listId}/items/{itemId}
  name: string, quantity: number, unit: string?, note: string?
  isChecked: boolean, imageUrl: string?, createdAt: timestamp

users/{uid}/receipts/{receiptId}
  storeId, storeName, purchasedAt, source, items: [{name, price, quantity}], rawText?

priceObservations/{observationId}          ← delt, anonym, append-only
  storeChainId, itemName, itemNameNormalized, price, observedAt, contributedAt, market

currentPrices/{market}-{storeChainId}-{safeItemName}   ← delt, "siste kjente pris"
  storeChainId, itemName, itemNameNormalized, price, lastObservedAt, sampleCount, market

storeLayouts/{branchId}                    ← delt, crowdsourcet, "siste innsending vinner"
  branchId, chainName, categoryOrder: string[], updatedAt
```

`priceObservations`/`currentPrices` bærer aldri en uid — hvem som bidro er ikke lagret, kun vare+pris+butikk+dato. `market`-feltet (se `lib/config/market.dart`) finnes allerede på alle nye rader, klar for et fremtidig land nummer to uten migrering.

**Avkrysning (`isChecked`) påvirker aldri prisberegningen** — det betyr bare "i handlekurven akkurat nå", ikke en bekreftelse på at varen faktisk ble kjøpt til den planlagte prisen/butikken.

## Sikkerhet og personvern (GDPR)

Firestore-regler ([firestore.rules](firestore.rules)): en bruker kan kun lese/skrive sine *egne* lister/varer/kvitteringer (`isOwner`), mens de delte samlingene (`priceObservations`, `currentPrices`, `storeLayouts`) er lesbare av alle — også uinnlogget — men kun skrivbare av en innlogget bruker (anonym eller ekte), med enkel feltvalidering.

**Sletting av konto (`AccountService.deleteAllUserData`):** sletter i dag lister og varer, men **sletter foreløpig ikke `users/{uid}/receipts`** — kjent, uløst GDPR-hull, se prosjektnotater.

**"Annet"-kvitteringer (IKEA, Kid, alt som ikke er en kjent dagligvarekjede)** kan lagres i egen historikk, men deles aldri til den felles prisdatabasen — bryteren for anonym deling er deaktivert så snart "Annet" er valgt som butikk.

## Infrastruktur

- Firebase-prosjektet kjører på Blaze (betal-etter-bruk), oppgradert fra Spark 2026-09-18 for å kunne kjøre `functions/nearbyStores` — en Cloud Function som proxyer butikksøk mot Overpass API server-til-server, siden Overpass' hovedserver ikke sender CORS-header til nettleserkall. Reell kostnad forventes å holde seg innenfor gratiskvoten.
- **Ingen git-fjernserver koblet til ennå** — koden lever kun lokalt. Se prosjektnotater for status på GitHub/CI-oppsett.
- **Ingen automatisert CI/deploy ennå** — `flutter analyze`, `flutter test`, `flutter build web` og `firebase deploy` kjøres manuelt.
- **Ingen feilovervåking i produksjon ennå** (Crashlytics/Sentry) — se prosjektnotater.

## Kjøre appen lokalt

```bash
flutter run -d chrome --dart-define-from-file=config/kassalapp.json
```

## Kjøre tester

```bash
flutter test
flutter analyze
```

## Bygge og deploye (web)

```bash
flutter build web --release --dart-define-from-file=config/kassalapp.json
firebase deploy --only hosting
```

Kjør `firebase deploy --only firestore:rules` etter enhver endring i `firestore.rules`, og gjør det *før* appkoden som avhenger av den nye regelen deployes, for å unngå tilgang-nektet-feil i produksjon.
