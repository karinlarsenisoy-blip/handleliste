# Handleliste — spesifikasjon

Kodet fra bunnen med samme Flutter + Firebase-mønster som ble øvd inn i **To-do-appen** (`../To do app`), gjenbrukt direkte: samme arkitektur (Auth → tabs → kategorier → rader), samme angre-mønster, samme sikkerhetsregler-struktur — kun datamodellen er tilpasset til varer i en handleliste i stedet for oppgaver.

## Teknologistack

| Del | Valg |
|---|---|
| UI-rammeverk | Flutter (Dart), Material 3 |
| Autentisering | Firebase Authentication (e-post/passord + Google) |
| Database | Cloud Firestore |
| Firebase-prosjekt | `handleliste-f1659` (gjenbrukt fra det opprinnelige FlutterFlow-forsøket) |
| Testing | `flutter_test` + `fake_cloud_firestore` |

## Mappestruktur

```
lib/
  main.dart                    Starter Firebase, viser AuthGate
  firebase_options.dart        Autogenerert av FlutterFire CLI — prosjektnøkler
  models/
    shopping_list.dart          Datamodellen ShoppingList (id, name, order) — «fanen»
    category.dart                Datamodellen Category (id, name, order)
    item.dart                    Datamodellen Item (id, name, quantity, unit, note, isChecked)
  services/
    list_service.dart            All kommunikasjon med Firestore for lister (CRUD + angre)
    category_service.dart        Kategorier (CRUD + rekkefølge + angre)
    item_service.dart            Varer (CRUD + avhuking + angre)
    account_service.dart         Sletting av all brukerdata + Auth-konto (GDPR)
  screens/
    auth_gate.dart               Viser innlogging eller liste-siden basert på status
    sign_in_screen.dart          Logg inn / opprett konto (e-post + passord + Google)
    lists_page.dart               Toppnivå: TabBar med listene, eier Scaffold/AppBar
    categories_page.dart         Innholdet i én liste: liste over kategorier (CategoriesView)
  widgets/
    category_tile.dart           Én kategori — utvidbar, med omdøp/slett og «legg til vare»
    item_tile.dart               Én vare — avkrysning, mengde/enhet, notat, rediger, sveip-og-slett
    item_edit_dialog.dart        Dialog for å redigere navn/antall/enhet/notat
```

## Arkitektur — hvordan delene henger sammen

```
main.dart
  └─ Firebase.initializeApp()
  └─ HandlelisteApp (MaterialApp)
       └─ AuthGate
            ├─ (ikke innlogget) → SignInScreen
            └─ (innlogget)      → ListsPage(uid)
                                     └─ TabBar (én fane per liste, f.eks. «Ukehandel», «Bursdag»)
                                          └─ CategoriesView (én per fane)
                                               └─ CategoryTile (én per kategori, dra-og-slippbar)
                                                    └─ ItemTile (én per vare)
```

- **AuthGate** lytter på `FirebaseAuth.instance.authStateChanges()`.
- **ListsPage** lytter på `ListService.watchLists(uid)` og holder en `TabController` som lages på nytt hver gang antall lister endres. AppBar-knappene (omdøp/slett liste) virker på den listen som er valgt akkurat nå.
- **CategoriesView** (i `categories_page.dart`) er innholdet i én liste: et «legg til kategori»-felt og en dra-og-slippbar liste av `CategoryTile`. Holdes i live på tvers av fanebytte via `AutomaticKeepAliveClientMixin`.
- **CategoryTile** lytter på `ItemService.watchItems(uid, listId, categoryId)` for sine egne varer.
- **ItemTile** viser navn, avkrysningsboks («i handlekurven»), antall/enhet og eventuelt notat. Sveip mot venstre sletter (med angre). Redigeringsknappen åpner `item_edit_dialog.dart` for navn/antall/enhet/notat.
- **ListService / CategoryService / ItemService** er de eneste stedene som snakker med Firestore. Alle tre eksponerer «slett + angre»-par: sletting returnerer et øyeblikksbilde av det som ble slettet, og en tilhørende `restore*`-metode skriver det tilbake uendret (samme dokument-id-er).

## Datamodell (Firestore)

```
users/{uid}/lists/{listId}
  name: string
  order: number
  createdAt: timestamp

users/{uid}/lists/{listId}/categories/{categoryId}
  name: string
  order: number                ← styrer rekkefølgen (dra-og-slipp)
  createdAt: timestamp

users/{uid}/lists/{listId}/categories/{categoryId}/items/{itemId}
  name: string
  quantity: number
  unit: string?                 f.eks. "stk", "kg", "l"
  note: string?
  isChecked: boolean            ← lagt i handlekurven / kjøpt
  createdAt: timestamp
```

En **liste** (f.eks. «Ukehandel»/«Bursdag») er det øverste nivået — hver liste har sitt eget, fullstendig uavhengige sett med kategorier og varer. Kategoriene tilsvarer typisk gangene/avdelingene i butikken («Meieri», «Frukt & grønt», «Non-food»).

**Rekkefølge:** Nye lister og kategorier får `order` satt til gjeldende tidspunkt i millisekunder, slik at de alltid havner sist blant eksisterende (små, normaliserte) tall. Når du drar en kategori til en ny plass, skrives `order` om for *alle* kategoriene i listen til 0, 1, 2, … (`CategoryService.reorderCategories`).

**Angre (undo):** `deleteList`/`deleteCategory`/`deleteItem` henter alltid ut rådataene *før* de sletter, og returnerer dem. UI-et viser en `SnackBar` med en ANGRE-knapp i 6 sekunder.

## Sikkerhet og personvern (GDPR)

Firestore-regler ([firestore.rules](firestore.rules)) håndhever at en bruker kun kan lese/skrive sine *egne* data, uansett nivå, og validerer at navn faktisk er fornuftige tekststrenger:

```
match /users/{userId}/lists/{listId} {
  allow read, delete: if isOwner(userId);
  allow create, update: if isOwner(userId) && isValidName(request.resource.data.name);
  match /categories/{categoryId} {
    allow read, delete: if isOwner(userId);
    allow create, update: if isOwner(userId) && isValidName(request.resource.data.name);
    match /items/{itemId} {
      allow read, delete: if isOwner(userId);
      allow create, update: if isOwner(userId) && isValidName(request.resource.data.name);
    }
  }
}
```

**Sletting av konto (`AccountService`):** Kontomenyen (personikonet øverst til høyre) har "Slett konto". Dette henter og sletter *all* Firestore-data for brukeren, deretter selve Firebase Auth-kontoen — samme "fersk innlogging kreves"-flyt som i To-do-appen.

## Kjent utgangspunkt / neste steg

- Firebase-prosjektet `handleliste-f1659` fantes fra før (opprettet for et tidligere FlutterFlow-forsøk, se `Handleliste dokumentasjon.docx`) og er nå koblet til denne Flutter-kodebasen med FlutterFire CLI (web, Android, iOS).
- **Ikke gjort ennå:** `firestore.rules` er skrevet men ikke deployet til det live prosjektet (`firebase deploy --only firestore:rules`) — gjør dette før appen brukes med ekte data. Sjekk også at Email/Password og Google er skrudd på under `Authentication → Sign-in method` i Firebase-konsollen.
- Kvitteringsscanner (nevnt i den opprinnelige dokumentasjonen) er ikke en del av denne runden — det er et naturlig neste steg når grunnmuren (lister/kategorier/varer) fungerer.
- Ingen dra-og-slipp for lister eller for varer innad i en kategori (kun kategorier kan dras) — samme begrensning som i To-do-appen.

## Kjøre appen lokalt

```bash
flutter run -d chrome
```

## Kjøre tester

```bash
flutter test
```
