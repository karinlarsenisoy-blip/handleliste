import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/receipt.dart';
import 'package:handleliste_app/models/receipt_item.dart';
import 'package:handleliste_app/services/receipt_service.dart';

Receipt _receipt({
  required String storeId,
  required DateTime purchasedAt,
  required List<ReceiptItem> items,
  ReceiptSource source = ReceiptSource.pastedText,
}) {
  return Receipt(
    id: '',
    storeId: storeId,
    storeName: storeId,
    purchasedAt: purchasedAt,
    source: source,
    items: items,
  );
}

void main() {
  group('ReceiptService.isDuplicateOf', () {
    test('flags same store, same day, same items — even from a different source', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReceiptService(firestore: firestore);
      await service.addReceipt(
        'u1',
        _receipt(
          storeId: 'kiwi',
          purchasedAt: DateTime(2026, 9, 1),
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ),
      );

      final candidate = _receipt(
        storeId: 'kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        source: ReceiptSource.photo,
        items: [ReceiptItem(name: 'melk', price: 23.90, quantity: 1)],
      );

      expect(await service.isDuplicateOf('u1', candidate), isTrue);
    });

    test('does not flag a different store as a duplicate', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReceiptService(firestore: firestore);
      await service.addReceipt(
        'u1',
        _receipt(
          storeId: 'kiwi',
          purchasedAt: DateTime(2026, 9, 1),
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ),
      );

      final candidate = _receipt(
        storeId: 'rema1000',
        purchasedAt: DateTime(2026, 9, 1),
        items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
      );

      expect(await service.isDuplicateOf('u1', candidate), isFalse);
    });

    test('does not flag a different day as a duplicate', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReceiptService(firestore: firestore);
      await service.addReceipt(
        'u1',
        _receipt(
          storeId: 'kiwi',
          purchasedAt: DateTime(2026, 9, 1),
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ),
      );

      final candidate = _receipt(
        storeId: 'kiwi',
        purchasedAt: DateTime(2026, 9, 8),
        items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
      );

      expect(await service.isDuplicateOf('u1', candidate), isFalse);
    });

    test('does not flag a different item set as a duplicate', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReceiptService(firestore: firestore);
      await service.addReceipt(
        'u1',
        _receipt(
          storeId: 'kiwi',
          purchasedAt: DateTime(2026, 9, 1),
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ),
      );

      final candidate = _receipt(
        storeId: 'kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1), ReceiptItem(name: 'Ost', price: 85.90)],
      );

      expect(await service.isDuplicateOf('u1', candidate), isFalse);
    });

    test('does not mix up different users', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ReceiptService(firestore: firestore);
      await service.addReceipt(
        'u1',
        _receipt(
          storeId: 'kiwi',
          purchasedAt: DateTime(2026, 9, 1),
          items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
        ),
      );

      final candidate = _receipt(
        storeId: 'kiwi',
        purchasedAt: DateTime(2026, 9, 1),
        items: [ReceiptItem(name: 'Melk', price: 23.90, quantity: 1)],
      );

      expect(await service.isDuplicateOf('u2', candidate), isFalse);
    });
  });
}
