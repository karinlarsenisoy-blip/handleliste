import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/price_observation.dart';
import 'package:handleliste_app/services/price_service.dart';

void main() {
  group('PriceService', () {
    test('contributing an observation creates a current-price row', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PriceService(firestore: firestore);

      await service.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 27.90,
        observedAt: DateTime(2026, 9, 1),
      ));

      final results = await service.searchCurrentPrices('bana');
      expect(results, hasLength(1));
      expect(results.first.storeChainId, 'kiwi');
      expect(results.first.price, 27.90);
      expect(results.first.sampleCount, 1);
    });

    test('a second observation for the same item+chain updates the row and bumps the sample count', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PriceService(firestore: firestore);

      await service.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 27.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await service.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'bananer',
        price: 24.90,
        observedAt: DateTime(2026, 9, 8),
      ));

      final results = await service.searchCurrentPrices('bananer');
      expect(results, hasLength(1));
      expect(results.first.price, 24.90);
      expect(results.first.sampleCount, 2);
    });

    test('search returns matches across chains, cheapest first', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PriceService(firestore: firestore);

      await service.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 27.90,
        observedAt: DateTime(2026, 9, 1),
      ));
      await service.contributeObservation(PriceObservation(
        storeChainId: 'rema1000',
        itemName: 'Bananer',
        price: 22.90,
        observedAt: DateTime(2026, 9, 1),
      ));

      final results = await service.searchCurrentPrices('banan');
      expect(results, hasLength(2));
      expect(results.first.storeChainId, 'rema1000');
      expect(results.first.price, 22.90);
      expect(results.last.storeChainId, 'kiwi');
    });

    test('search does not match an unrelated item', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PriceService(firestore: firestore);

      await service.contributeObservation(PriceObservation(
        storeChainId: 'kiwi',
        itemName: 'Bananer',
        price: 27.90,
        observedAt: DateTime(2026, 9, 1),
      ));

      expect(await service.searchCurrentPrices('melk'), isEmpty);
    });
  });
}
