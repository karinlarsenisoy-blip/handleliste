import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/models/receipt.dart';
import 'package:handleliste_app/models/receipt_item.dart';
import 'package:handleliste_app/screens/receipts_page.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/receipt_service.dart';

/// Returns fixed, known prices per item name instead of hitting
/// Firestore/Kassalapp — for checking the retroactive "was this cheaper
/// elsewhere" comparison with fully controlled data.
class _FixedCheapestStoreService extends CheapestStoreService {
  _FixedCheapestStoreService(this.byItemName)
      : super(priceService: PriceService(firestore: FakeFirebaseFirestore()));

  final Map<String, List<({String storeName, num price, DateTime lastObservedAt})>> byItemName;

  @override
  Future<List<({String storeName, num price, DateTime lastObservedAt})>> pricesForItem(String itemName) async {
    return byItemName[itemName] ?? [];
  }
}

void main() {
  const uid = 'test-uid';

  testWidgets('flags an item as cheaper elsewhere, and leaves an item alone when nothing cheaper is known',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final receiptService = ReceiptService(firestore: firestore);
    await receiptService.addReceipt(
      uid,
      Receipt(
        id: '',
        storeId: 'kiwi',
        storeName: 'Kiwi',
        purchasedAt: DateTime(2026, 9, 19),
        source: ReceiptSource.photo,
        items: [
          ReceiptItem(name: 'Melk', price: 24.90, quantity: 1),
          ReceiptItem(name: 'Brød', price: 32.90, quantity: 1),
        ],
      ),
    );

    final cheapestStoreService = _FixedCheapestStoreService({
      // Paid 24.90 for Melk - Rema currently has it cheaper.
      'Melk': [(storeName: 'Rema 1000', price: 19.90, lastObservedAt: DateTime.now())],
      // Paid 32.90 for Brød - nothing cheaper known anywhere.
      'Brød': [(storeName: 'Kiwi', price: 32.90, lastObservedAt: DateTime.now())],
    });

    await tester.pumpWidget(MaterialApp(
      home: ReceiptsPage(uid: uid, receiptService: receiptService, cheapestStoreService: cheapestStoreService),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();

    expect(find.text('1 av 2 varer er billigere andre steder nettopp nå.'), findsOneWidget);
    expect(find.text('Billigere hos Rema 1000: 19.90 kr'), findsOneWidget);
    // Brød has nothing cheaper - no such subtitle for it.
    expect(find.textContaining('Billigere hos Kiwi'), findsNothing);
  });

  testWidgets('shows a clear "nothing cheaper" message when every item is already the best known price',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final receiptService = ReceiptService(firestore: firestore);
    await receiptService.addReceipt(
      uid,
      Receipt(
        id: '',
        storeId: 'rema1000',
        storeName: 'Rema 1000',
        purchasedAt: DateTime(2026, 9, 19),
        source: ReceiptSource.photo,
        items: [ReceiptItem(name: 'Egg', price: 49.90, quantity: 1)],
      ),
    );

    final cheapestStoreService = _FixedCheapestStoreService({
      'Egg': [(storeName: 'Rema 1000', price: 49.90, lastObservedAt: DateTime.now())],
    });

    await tester.pumpWidget(MaterialApp(
      home: ReceiptsPage(uid: uid, receiptService: receiptService, cheapestStoreService: cheapestStoreService),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rema 1000'));
    await tester.pumpAndSettle();

    expect(find.text('Ingen av varene var billigere andre steder nettopp nå.'), findsOneWidget);
  });
}
