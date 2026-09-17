import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/price_observation.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/price_service.dart';

void main() {
  group('CheapestStoreService', () {
    test('ranks stores by list coverage first, then cheapest total, using our own price data', () async {
      final firestore = FakeFirebaseFirestore();
      final priceService = PriceService(firestore: firestore);
      final service = CheapestStoreService(priceService: priceService);

      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 24.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'rema1000',
        itemName: 'Bananer',
        price: 22.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Melk',
        price: 24.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      // Rema has no known price for Melk — only Bananer.

      final results = await service.findCheapestStores(['Bananer', 'Melk']);

      expect(results, hasLength(2));
      expect(results[0].storeName, 'Kiwi');
      expect(results[0].total, 49.80);
      expect(results[0].matchedItemCount, 2);
      expect(results[1].storeName, 'Rema 1000');
      expect(results[1].total, 22.90);
      expect(results[1].matchedItemCount, 1);
    });

    test('returns an empty list when nothing is known about any item', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CheapestStoreService(priceService: PriceService(firestore: firestore));

      expect(await service.findCheapestStores(['Noe helt ukjent']), isEmpty);
    });
  });

  group('CheapestStoreService.findCheapestSplit', () {
    test('assigns each item to whichever store is individually cheapest for it', () async {
      final firestore = FakeFirebaseFirestore();
      final priceService = PriceService(firestore: firestore);
      final service = CheapestStoreService(priceService: priceService);

      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 24.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'rema1000',
        itemName: 'Bananer',
        price: 22.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await priceService.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Melk',
        price: 19.90,
        observedAt: DateTime(2026, 9, 1),
      ));

      final split = await service.findCheapestSplit(['Bananer', 'Melk']);

      expect(split.assignments, hasLength(2));
      expect(split.total, 22.90 + 19.90);
      expect(split.unmatchedItems, isEmpty);

      final byStore = split.assignmentsByStore;
      expect(byStore['Rema 1000']!.single.itemName, 'Bananer');
      expect(byStore['Kiwi']!.single.itemName, 'Melk');
    });

    test('lists items with no known price as unmatched instead of guessing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CheapestStoreService(priceService: PriceService(firestore: firestore));

      final split = await service.findCheapestSplit(['Noe helt ukjent']);

      expect(split.assignments, isEmpty);
      expect(split.unmatchedItems, ['Noe helt ukjent']);
      expect(split.total, 0);
    });
  });
}
