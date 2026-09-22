import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/screens/home_screen.dart';
import 'package:handleliste_app/services/cheapest_store_service.dart';
import 'package:handleliste_app/services/item_service.dart';
import 'package:handleliste_app/services/list_service.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/receipt_service.dart';

void main() {
  Future<void> pumpHomeScreen(WidgetTester tester, {required bool isAnonymous}) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        uid: 'test-uid',
        isAnonymous: isAnonymous,
        cheapestStoreService: CheapestStoreService(priceService: PriceService(firestore: firestore)),
        receiptService: ReceiptService(firestore: firestore),
        listService: ListService(firestore: firestore),
        itemService: ItemService(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('HomeScreen — guest gating', () {
    testWidgets('an anonymous user tapping "Skann en kvittering" sees the account-required gate, not the scanner',
        (tester) async {
      await pumpHomeScreen(tester, isAnonymous: true);

      await tester.tap(find.text('Skann en kvittering'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Opprett en konto for å skanne og lagre kvitteringer'), findsOneWidget);
    });

    testWidgets('an anonymous user tapping the voice-entry shortcut sees the account-required gate, not the mic flow',
        (tester) async {
      await pumpHomeScreen(tester, isAnonymous: true);

      await tester.tap(find.text('Si varenavn til en liste'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Opprett en konto for å legge varer i en handleliste'), findsOneWidget);
    });

    testWidgets(
        'an anonymous user searching and tapping "Legg i en handleliste" sees the account-required gate, not a list picker',
        (tester) async {
      await pumpHomeScreen(tester, isAnonymous: true);

      await tester.enterText(find.byType(TextField).first, 'melk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('i en handleliste'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Opprett en konto for å legge varer i en handleliste'), findsOneWidget);
    });
  });
}
