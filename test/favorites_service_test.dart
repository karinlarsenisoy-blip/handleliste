import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/receipt.dart';
import 'package:handleliste_app/models/receipt_item.dart';
import 'package:handleliste_app/services/favorites_service.dart';
import 'package:handleliste_app/services/receipt_service.dart';

void main() {
  group('FavoritesService', () {
    test('an item bought on two separate receipts becomes a favorite', () async {
      final firestore = FakeFirebaseFirestore();
      final receiptService = ReceiptService(firestore: firestore);
      final service = FavoritesService(receiptService: receiptService);

      await receiptService.addReceipt('u1', Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        source: ReceiptSource.pastedText,
        items: [ReceiptItem(name: 'Melk', price: 24.90, quantity: 1)],
      ));
      await receiptService.addReceipt('u1', Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 8),
        source: ReceiptSource.pastedText,
        items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
      ));

      final favorites = await service.mostPurchased('u1');
      expect(favorites, hasLength(1));
      expect(favorites.first.name, 'Melk');
      expect(favorites.first.purchaseCount, 2);
      expect(favorites.first.lastPurchasedAt, DateTime(2026, 9, 8));
      expect(favorites.first.lastPrice, 23.90);
    });

    test('an item bought only once is not a favorite', () async {
      final firestore = FakeFirebaseFirestore();
      final receiptService = ReceiptService(firestore: firestore);
      final service = FavoritesService(receiptService: receiptService);

      await receiptService.addReceipt('u1', Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        source: ReceiptSource.pastedText,
        items: [ReceiptItem(name: 'Kaviar', price: 49.90, quantity: 1)],
      ));

      expect(await service.mostPurchased('u1'), isEmpty);
    });

    test('different casings of the same name are merged into one favorite', () async {
      final firestore = FakeFirebaseFirestore();
      final receiptService = ReceiptService(firestore: firestore);
      final service = FavoritesService(receiptService: receiptService);

      await receiptService.addReceipt('u1', Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        source: ReceiptSource.pastedText,
        items: [ReceiptItem(name: 'BANANER', price: 22.90, quantity: 1)],
      ));
      await receiptService.addReceipt('u1', Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 8),
        source: ReceiptSource.pastedText,
        items: [ReceiptItem(name: 'bananer', price: 24.90, quantity: 1)],
      ));

      final favorites = await service.mostPurchased('u1');
      expect(favorites, hasLength(1));
      expect(favorites.first.purchaseCount, 2);
    });

    test('ranks the item bought most often first', () async {
      final firestore = FakeFirebaseFirestore();
      final receiptService = ReceiptService(firestore: firestore);
      final service = FavoritesService(receiptService: receiptService);

      for (final date in [DateTime(2026, 9, 1), DateTime(2026, 9, 8), DateTime(2026, 9, 15)]) {
        await receiptService.addReceipt('u1', Receipt(
          id: '',
          storeId: 'kiwi',
          storeName: 'Kiwi',
          purchasedAt: date,
          source: ReceiptSource.pastedText,
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ));
      }
      for (final date in [DateTime(2026, 9, 1), DateTime(2026, 9, 8)]) {
        await receiptService.addReceipt('u1', Receipt(
          id: '',
          storeId: 'kiwi',
          storeName: 'Kiwi',
          purchasedAt: date,
          source: ReceiptSource.pastedText,
          items: [ReceiptItem(name: 'Ost', price: 85.90, quantity: 1)],
        ));
      }

      final favorites = await service.mostPurchased('u1');
      expect(favorites.map((f) => f.name).toList(), ['Melk', 'Ost']);
    });

    test('does not mix up different users', () async {
      final firestore = FakeFirebaseFirestore();
      final receiptService = ReceiptService(firestore: firestore);
      final service = FavoritesService(receiptService: receiptService);

      for (final date in [DateTime(2026, 9, 1), DateTime(2026, 9, 8)]) {
        await receiptService.addReceipt('u1', Receipt(
          id: '',
          storeId: 'kiwi',
          storeName: 'Kiwi',
          purchasedAt: date,
          source: ReceiptSource.pastedText,
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ));
      }

      expect(await service.mostPurchased('u2'), isEmpty);
    });
  });
}
