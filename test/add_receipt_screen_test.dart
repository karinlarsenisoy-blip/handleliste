import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/screens/add_receipt_screen.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/receipt_service.dart';

void main() {
  const uid = 'test-uid';

  testWidgets('the "Del prisene anonymt" switch is disabled once "Annet" (non-grocery) is selected', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(MaterialApp(
      home: AddReceiptScreen(
        uid: uid,
        receiptService: ReceiptService(firestore: firestore),
        priceService: PriceService(firestore: firestore),
      ),
    ));
    await tester.pumpAndSettle();

    // Defaults to Kiwi — sharing starts enabled.
    var switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.onChanged, isNotNull);
    expect(switchWidget.value, isTrue);

    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annet').last);
    await tester.pumpAndSettle();

    switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.onChanged, isNull, reason: 'sharing must not be toggleable for a non-grocery store');
    expect(switchWidget.value, isFalse);
    expect(find.textContaining('Ikke tilgjengelig for «Annet»'), findsOneWidget);
  });
}
