import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/price_observation.dart';
import 'package:handleliste_app/models/store_location.dart';
import 'package:handleliste_app/screens/active_trip_screen.dart';
import 'package:handleliste_app/screens/cheapest_store_screen.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/item_service.dart';
import 'package:handleliste_app/services/location_service.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/store_layout_service.dart';
import 'package:handleliste_app/services/store_locator_service.dart';

/// Always reports the same fixed position — stands in for "the user's real
/// GPS location" without needing a real browser geolocation permission.
class _FixedLocationService extends LocationService {
  _FixedLocationService(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  Future<LocationResult> getCurrentPosition() async => LocationResult.success(latitude, longitude);
}

/// Returns a canned set of nearby branches instead of calling the real
/// Overpass-backed Cloud Function — stands in for "what OpenStreetMap
/// happens to know about this particular part of Norway", so the same
/// reachability logic can be exercised for several simulated regions
/// without depending on live, ever-changing OSM data.
class _FakeStoreLocatorService extends StoreLocatorService {
  _FakeStoreLocatorService(this.stores);
  final List<StoreLocation> stores;

  @override
  Future<List<StoreLocation>> findNearby(double latitude, double longitude, {double radiusMeters = 3000}) async =>
      stores;
}

void main() {
  const uid = 'test-uid';
  const listId = 'list-1';
  const listName = 'Ukehandel';

  // Same list on every test: Melk, Brød, Bananer. Prices are chosen so the
  // single-store ranking, the unrestricted split, and the reachability-aware
  // split each pick a different, independently verifiable winner — if any of
  // the three ever regresses, only that one test should fail.
  //
  //             Melk   Brød   Bananer   Total (3/3 = full coverage)
  //   Kiwi       20      30      15      65   <- cheapest FULL-coverage store
  //   Rema 1000  18      32      16      66
  //   Coop Extra 19      28       -      47   <- cheapest raw total, but only 2/3
  Future<FakeFirebaseFirestore> seedListAndPrices() async {
    final firestore = FakeFirebaseFirestore();
    final itemService = ItemService(firestore: firestore);
    final priceService = PriceService(firestore: firestore);
    final now = DateTime.now();

    await itemService.addItem(uid, listId, 'Melk');
    await itemService.addItem(uid, listId, 'Brød');
    await itemService.addItem(uid, listId, 'Bananer');

    Future<void> price(String chainId, String itemName, num price) => priceService.contributeObservation(
          PriceObservation(storeChainId: chainId, itemName: itemName, price: price, observedAt: now),
        );

    await price('kiwi', 'Melk', 20.00);
    await price('kiwi', 'Brød', 30.00);
    await price('kiwi', 'Bananer', 15.00);
    await price('rema1000', 'Melk', 18.00);
    await price('rema1000', 'Brød', 32.00);
    await price('rema1000', 'Bananer', 16.00);
    await price('coop_extra', 'Melk', 19.00);
    await price('coop_extra', 'Brød', 28.00);
    // Coop Extra has no known price for Bananer at all.

    return firestore;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeFirebaseFirestore firestore, {
    LocationService? locationService,
    StoreLocatorService? storeLocatorService,
  }) async {
    // The split tab's content (savings banner, several stops, totals,
    // confirm button) is easily taller than the default 800x600 test
    // surface — without this, anything below the fold is simply never
    // built by the ListView and finders for it report "not found" even
    // though the real, scrollable app would show it fine.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(MaterialApp(
      home: CheapestStoreScreen(
        uid: uid,
        listId: listId,
        listName: listName,
        itemService: ItemService(firestore: firestore),
        cheapestStoreService: CheapestStoreService(priceService: PriceService(firestore: firestore)),
        storeLayoutService: StoreLayoutService(firestore: firestore),
        locationService: locationService ?? _FixedLocationService(59.9, 10.7),
        storeLocatorService: storeLocatorService ?? _FakeStoreLocatorService(const []),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('CheapestStoreScreen — Én butikk (single store)', () {
    testWidgets('ranks the cheapest FULL-coverage store first, ahead of a cheaper but partial one', (tester) async {
      final firestore = await seedListAndPrices();
      await pumpScreen(tester, firestore);

      // Kiwi (65 kr, 3/3) should rank above Rema 1000 (66 kr, 3/3), which
      // should rank above Coop Extra (47 kr, 2/3) despite its lower total —
      // coverage beats price, per CheapestStoreService's documented rule.
      final kiwiY = tester.getTopLeft(find.text('Kiwi')).dy;
      final remaY = tester.getTopLeft(find.text('Rema 1000')).dy;
      final coopY = tester.getTopLeft(find.text('Coop Extra')).dy;

      expect(kiwiY, lessThan(remaY));
      expect(remaY, lessThan(coopY));
      expect(find.text('65.00 kr'), findsOneWidget);
      expect(find.text('66.00 kr'), findsOneWidget);
      expect(find.text('47.00 kr'), findsOneWidget);
    });
  });

  group('CheapestStoreScreen — Handletur (split), no location', () {
    testWidgets('assigns each item to wherever it is individually cheapest, across all 3 stores', (tester) async {
      final firestore = await seedListAndPrices();
      await pumpScreen(tester, firestore);

      await tester.tap(find.text('Handletur'));
      await tester.pumpAndSettle();

      // Melk -> Rema 1000 (18), Brød -> Coop Extra (28), Bananer -> Kiwi (15).
      expect(find.text('Kiwi'), findsOneWidget);
      expect(find.text('Rema 1000'), findsOneWidget);
      expect(find.text('Coop Extra'), findsOneWidget);
      expect(find.text('18.00 kr'), findsOneWidget);
      expect(find.text('28.00 kr'), findsOneWidget);
      expect(find.text('15.00 kr'), findsOneWidget);
      expect(find.textContaining('61.00 kr'), findsOneWidget); // 18 + 28 + 15
    });
  });

  group('CheapestStoreScreen — Handletur, reachability across two simulated Norwegian locations', () {
    testWidgets('with all 3 chains reachable nearby, the split is unchanged', (tester) async {
      final firestore = await seedListAndPrices();
      // "Oslo-like": a branch of every chain in the list's prices is nearby.
      final locator = _FakeStoreLocatorService([
        StoreLocation(branchId: 'osm-1', chainName: 'Kiwi', name: 'Kiwi Grünerløkka', latitude: 59.92, longitude: 10.75),
        StoreLocation(branchId: 'osm-2', chainName: 'Rema 1000', name: 'Rema 1000 Torshov', latitude: 59.94, longitude: 10.76),
        StoreLocation(
            branchId: 'osm-3', chainName: 'Coop Extra', name: 'Coop Extra Sagene', latitude: 59.93, longitude: 10.74),
      ]);
      await pumpScreen(tester, firestore, storeLocatorService: locator);

      await tester.tap(find.text('Bruk min posisjon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Handletur'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fant ingen kjent'), findsNothing);
      expect(find.text('18.00 kr'), findsOneWidget); // Melk @ Rema 1000, unchanged
      expect(find.text('28.00 kr'), findsOneWidget); // Brød @ Coop Extra, unchanged
      expect(find.text('15.00 kr'), findsOneWidget); // Bananer @ Kiwi, unchanged
    });

    testWidgets('with only Kiwi and Rema 1000 reachable, Brød is reassigned away from the unreachable Coop Extra',
        (tester) async {
      final firestore = await seedListAndPrices();
      // "Small-town-like": no Coop Extra branch anywhere nearby.
      final locator = _FakeStoreLocatorService([
        StoreLocation(branchId: 'osm-10', chainName: 'Kiwi', name: 'Kiwi Sentrum', latitude: 69.65, longitude: 18.96),
        StoreLocation(
            branchId: 'osm-11', chainName: 'Rema 1000', name: 'Rema 1000 Sentrum', latitude: 69.66, longitude: 18.98),
      ]);
      await pumpScreen(tester, firestore, locationService: _FixedLocationService(69.65, 18.96), storeLocatorService: locator);

      await tester.tap(find.text('Bruk min posisjon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Handletur'));
      await tester.pumpAndSettle();

      // Coop Extra is unreachable, so the app should say so...
      expect(find.textContaining('Coop Extra'), findsWidgets);
      expect(find.textContaining('Fant ingen kjent'), findsOneWidget);
      // ...and Brød should move from Coop Extra (28 kr, unreachable) to
      // whichever of the two REACHABLE stores is cheapest for it: Kiwi (30 kr),
      // not Rema 1000 (32 kr).
      expect(find.text('30.00 kr'), findsOneWidget);
      expect(find.text('32.00 kr'), findsNothing);
      expect(find.text('28.00 kr'), findsNothing);
      // Melk and Bananer are unaffected (their cheapest stores were already reachable).
      expect(find.text('18.00 kr'), findsOneWidget);
      expect(find.text('15.00 kr'), findsOneWidget);
      // Only 2 stores now, not 3.
      expect(find.textContaining('2 butikker'), findsOneWidget);
    });
  });

  group('CheapestStoreScreen — confirming a route and checking items off', () {
    testWidgets('"Bekreft rute" opens ActiveTripScreen with the split\'s stores, and checking an item persists it',
        (tester) async {
      final firestore = await seedListAndPrices();
      await pumpScreen(tester, firestore);

      await tester.tap(find.text('Handletur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekreft rute og start handletur'));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveTripScreen), findsOneWidget);
      expect(find.text('0 av 3 varer i kurven'), findsOneWidget);

      await tester.tap(find.text('Bananer'));
      await tester.pumpAndSettle();

      expect(find.text('1 av 3 varer i kurven'), findsOneWidget);

      // The checkbox is real, not just a local UI toggle: re-reading the
      // list from the same fake Firestore should show Bananer as checked.
      final items = await ItemService(firestore: firestore).watchItems(uid, listId).first;
      final bananer = items.firstWhere((i) => i.name == 'Bananer');
      expect(bananer.isChecked, isTrue);
    });
  });
}
