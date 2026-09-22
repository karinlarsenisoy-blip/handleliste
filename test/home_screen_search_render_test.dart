import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/screens/home_screen.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/item_service.dart';
import 'package:handleliste_app/services/list_service.dart';
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
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        uid: 'test-uid',
        isAnonymous: true,
        cheapestStoreService: _FixedCheapestStoreService(),
        receiptService: ReceiptService(firestore: firestore),
        listService: ListService(firestore: firestore),
        itemService: ItemService(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'baconpostei');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Kiwi'), findsOneWidget);
    expect(find.text('33.40 kr'), findsOneWidget);
  });

  testWidgets('a signed-in user can add the searched item to an existing list from the search result',
      (tester) async {
    const uid = 'test-uid';
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);
    await listService.addList(uid, 'Ukehandel');

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        uid: uid,
        isAnonymous: false,
        cheapestStoreService: _FixedCheapestStoreService(),
        receiptService: ReceiptService(firestore: firestore),
        listService: listService,
        itemService: itemService,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'baconpostei');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('i en handleliste'));
    await tester.pumpAndSettle();

    // The list-picker bottom sheet should now show "Ukehandel" to choose.
    await tester.tap(find.text('Ukehandel'));
    await tester.pumpAndSettle();

    final lists = await listService.watchLists(uid).first;
    final items = await itemService.watchItems(uid, lists.single.id).first;
    expect(items.single.name, 'baconpostei');
    expect(find.textContaining('lagt til i «Ukehandel»'), findsOneWidget);
  });
}
