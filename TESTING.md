# Testscenarier — "Finn billigst"

En sjekkliste for å teste kvitterings-/prislogikken, for både mennesker og Claude. Oppdater denne når testdataen i `TestDataSeeder` endres — tallene under må stemme med `lib/services/test_data_seeder.dart` til enhver tid.

## Oppsett

1. Logg inn (egen konto eller ny).
2. Profil → **"Legg til testdata (dev)"**.
3. Dette oppretter to lister («Ukehandel», «Hjem fra jobb») og legger inn disse **kjente, faste prisene** i vårt eget prisregister (uavhengig av Kassalapp):

| Vare | Kiwi | Rema 1000 | Coop Extra | Billigst |
|---|---|---|---|---|
| Bananer | 24,90 | **22,90** | 26,50 | Rema 1000 |
| Melk | 24,90 | **23,90** | 24,50 | Rema 1000 |
| Kjøttdeig | 79,90 | **74,90** | 82,90 | Rema 1000 |
| Ost | 89,90 | **85,90** | 91,90 | Rema 1000 |
| Brød* | 32,90 | **29,90** | 31,90 | Rema 1000 |
| Egg* | 52,90 | **49,90** | 54,90 | Rema 1000 |

\* Brød/Egg har priser i registeret, men er ikke varer på noen av testlistene — de er kun der for å teste `PriceService` isolert (se `price_service_test.dart`).

**Rema 1000 vinner på alle seks** — det er bevisst, så et riktig fungerende system alltid skal plukke Rema 1000 for disse varene, uansett hva Kassalapp måtte si (Kassalapp har uansett ikke Kiwi/Rema 1000 i sin database — se prosjektnotater).

## Deterministiske sjekker (skal alltid stemme, uavhengig av Kassalapp)

Åpne «Billigst for Ukehandel» → **Én butikk**:

- [ ] Rema 1000 skal vise minst 4 av sine varer (Melk, Bananer, Kjøttdeig, Ost) til de eksakte prisene i tabellen over.
- [ ] Trykk på Rema 1000-raden → detaljvisningen skal liste akkurat disse 4 varene med riktig pris, og "Sett i dag" (siden testdataen akkurat ble lagt inn).
- [ ] Ingen av de tre butikkene skal vise en pris som avviker fra tabellen for disse 4 varene.

Åpne **Flere butikker**:

- [ ] Melk, Bananer, Kjøttdeig og Ost skal alle være tildelt **Rema 1000** i splitten (siden Rema 1000 er billigst på alle fire — det finnes ingen bedre split for disse).
- [ ] Totalsummen for akkurat disse 4 varene skal være 23,90 + 22,90 + 74,90 + 85,90 = **207,60 kr**, uansett hva som skjer med resten av listen.

## Ikke-deterministiske sjekker (avhenger av Kassalapp sin livedata — kan endre seg)

Resten av Ukehandel-listen (Yoghurt, Smør, Epler, Poteter, Løk, Kyllingfilet, Oppvasktabletter, Toalettpapir) har **ingen** priser i vårt eget register — alt som vises for dem kommer fra Kassalapp sitt live-API, og kan derfor endre seg mellom hver test. Sjekk i stedet at *oppførselen* er fornuftig, ikke eksakte tall:

- [ ] Varer uten treff hos Kassalapp vises under "Ingen kjent pris" i splitten — ikke som en feil eller en tom rad.
- [ ] Ingen pris eldre enn 30 dager vises noe sted (fersk-teksten skal aldri si "Sett for 31+ dager siden" — sjekk `lib/services/cheapest_store_service.dart`s `_maxPriceAge` hvis dette dukker opp).
- [ ] Ingen butikk fra en ikke-dagligvare-kjede (f.eks. "Engrosnett", "Havaristen") dukker opp noe sted.
- [ ] Samme butikknavn vises aldri to ganger på grunn av ulik bokstavbruk (f.eks. "KIWI" og "Kiwi" som to rader).

## Sparetall-melding ("Flere butikker")

- [ ] Meldingen "Du sparer X kr" skal alltid referere til et tall lavere enn eller lik den beste enkelt-butikkens totalsum for de samme overlappende varene.
- [ ] Teksten skal eksplisitt si "X av dine Y varer" (ikke bare "X varer") når enkelt-butikken ikke dekker hele lista — sjekk at Y stemmer med det faktiske antallet varer på lista (12 for Ukehandel), ikke bare antallet med kjent pris.

## Produktbilder

- [ ] Skriv "melk" (eller et annet vanlig produktnavn) i "Ny vare"-feltet på en liste → forslagene som dukker opp skal ha miniatyrbilder (fra Kassalapp/Open Food Facts).
- [ ] Velg ett forslag → varen som legges til i lista skal vise det samme bildet ved siden av navnet.
- [ ] Varer lagt til med fritekst (ingen forslag valgt) skal vise et generisk handlekurv-ikon i stedet for et bilde — ikke en feil eller et tomt rom.
- [ ] Testdata lagt til via "Legg til testdata (dev)" har **ingen** bilder (den går utenom forslags-flyten) — det er forventet, ikke en feil.

## Kjente begrensninger å ikke rapportere som feil

- Kassalapp mangler Kiwi og Rema 1000 helt — kun vårt eget prisregister kan noensinne dekke disse to kjedene.
- Enkelt-ord-søk som "melk" alene kan gi dårlig relevans hos Kassalapp (de vekter ord som starter med "melk-" høyere) — prøv et mer spesifikt søk ("lettmelk") hvis resultatene ser rare ut.
- Splitten prøver ikke å veie besparelse opp mot reisetid mellom butikker ennå — det kommer med rute-funksjonen.
