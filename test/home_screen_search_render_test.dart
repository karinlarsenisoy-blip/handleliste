import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/screens/home_screen.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/receipt_service.dart';

/// Returns a fixed result set instead of hitting Firestore/Kassalapp — for
/// checking exactly what HomeScreen renders for a known, real price value
/// (33.4, matching a real "Baconpostei ovnsbakt 185g mills" entry a user
/// reported seeing with no visible price after a live search).
class _FixedCheapestStoreService extends CheapestStoreService {
  _FixedCheapestStoreService() : super(priceService: PriceService(firestore: FakeFirebaseFirestore()));

  @override
  Future<List<({String storeName, num price, DateTime lastObservedAt})>> pricesForItem(String itemName) async {
    return [
      (storeName: 'Kiwi', price: 33.4, lastObservedAt: DateTime.now()),
    ];
  }
}

void main() {
  testWidgets('HomeScreen search result shows the store name AND the price', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        uid: 'test-uid',
        isAnonymous: true,
        cheapestStoreService: _FixedCheapestStoreService(),
        receiptService: ReceiptService(firestore: FakeFirebaseFirestore()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'baconpostei');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Kiwi'), findsOneWidget);
    expect(find.text('33.40 kr'), findsOneWidget);
  });
}
