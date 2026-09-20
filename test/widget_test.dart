import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:handleliste_app/screens/lists_page.dart';
import 'package:handleliste_app/services/account_service.dart';
import 'package:handleliste_app/services/item_service.dart';
import 'package:handleliste_app/services/list_service.dart';

void main() {
  Future<void> pumpListsPage(
    WidgetTester tester, {
    required ListService listService,
    required ItemService itemService,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: ListsPage(
        uid: 'test-uid',
        listService: listService,
        itemService: itemService,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh user sees a prompt to add their first list', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpListsPage(
      tester,
      listService: ListService(firestore: firestore),
      itemService: ItemService(firestore: firestore),
    );

    expect(find.textContaining('Ingen lister ennå'), findsOneWidget);
  });

  testWidgets('can create two lists and add an item inside one of them', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpListsPage(
      tester,
      listService: ListService(firestore: firestore),
      itemService: ItemService(firestore: firestore),
    );

    final dialogTextField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // Add the "Ukehandel" list.
    await tester.tap(find.byTooltip('Ny liste'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField, 'Ukehandel');
    await tester.tap(find.text('Lagre'));
    await tester.pumpAndSettle();

    expect(find.text('Ukehandel'), findsWidgets);

    // Add a second "Bursdag" list.
    await tester.tap(find.byTooltip('Ny liste'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField, 'Bursdag');
    await tester.tap(find.text('Lagre'));
    await tester.pumpAndSettle();

    expect(find.text('Bursdag'), findsWidgets);

    // Add an item directly to the currently selected ("Ukehandel") list —
    // no category step, lists have no folder level.
    await tester.enterText(find.widgetWithText(TextField, 'Ny vare...'), 'Melk');
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();

    expect(find.text('Melk'), findsOneWidget);
  });

  testWidgets('deleting an item shows undo, and undo restores it', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);

    await listService.addList('test-uid', 'Ukehandel');
    final lists = await listService.watchLists('test-uid').first;
    await itemService.addItem('test-uid', lists.first.id, 'Melk');

    await pumpListsPage(tester, listService: listService, itemService: itemService);

    expect(find.text('Melk'), findsOneWidget);
    await tester.drag(find.text('Melk'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Melk'), findsNothing);
    expect(find.textContaining('ble slettet'), findsOneWidget);

    await tester.tap(find.text('ANGRE'));
    await tester.pumpAndSettle();

    expect(find.text('Melk'), findsOneWidget);
  });

  testWidgets('editing an item through the edit dialog updates its name and quantity', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);

    await listService.addList('test-uid', 'Ukehandel');
    final lists = await listService.watchLists('test-uid').first;
    await itemService.addItem('test-uid', lists.first.id, 'Gammelt navn');

    await pumpListsPage(tester, listService: listService, itemService: itemService);

    await tester.tap(find.byTooltip('Rediger vare'));
    await tester.pumpAndSettle();

    final dialogTextField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ).first;
    await tester.enterText(dialogTextField, 'Nytt navn');
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.text('Lagre'));
    await tester.pumpAndSettle();

    expect(find.text('Nytt navn'), findsOneWidget);
    expect(find.text('Gammelt navn'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('checking an item strikes it through', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);

    await listService.addList('test-uid', 'Ukehandel');
    final lists = await listService.watchLists('test-uid').first;
    await itemService.addItem('test-uid', lists.first.id, 'Melk');

    await pumpListsPage(tester, listService: listService, itemService: itemService);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Melk'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  test('deleteAllUserData removes every list and item for that user', () async {
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);
    final accountService = AccountService(firestore: firestore);

    await listService.addList('test-uid', 'Ukehandel');
    final lists = await listService.watchLists('test-uid').first;
    await itemService.addItem('test-uid', lists.first.id, 'Melk');

    // Another user's data must survive untouched.
    await listService.addList('other-uid', 'Privat');

    await accountService.deleteAllUserData('test-uid');

    expect(await listService.watchLists('test-uid').first, isEmpty);
    expect(await listService.watchLists('other-uid').first, hasLength(1));
  });
}
