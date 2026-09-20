import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/item_service.dart';
import 'package:handleliste_app/services/list_service.dart';
import 'package:handleliste_app/services/price_service.dart';
import 'package:handleliste_app/services/test_data_seeder.dart';

void main() {
  test('seedAll creates both lists with their items, and price observations', () async {
    final firestore = FakeFirebaseFirestore();
    final listService = ListService(firestore: firestore);
    final itemService = ItemService(firestore: firestore);
    final priceService = PriceService(firestore: firestore);
    final seeder = TestDataSeeder(
      listService: listService,
      itemService: itemService,
      priceService: priceService,
    );

    await seeder.seedAll('test-uid');

    final lists = await listService.watchLists('test-uid').first;
    expect(lists.map((l) => l.name), containsAll(['Ukehandel', 'Hjem fra jobb']));

    final weeklyList = lists.firstWhere((l) => l.name == 'Ukehandel');
    final weeklyItems = await itemService.watchItems('test-uid', weeklyList.id).first;
    expect(weeklyItems, hasLength(12));
    expect(weeklyItems.map((i) => i.name), containsAll(['Melk', 'Ost', 'Yoghurt', 'Smør']));

    final adHocList = lists.firstWhere((l) => l.name == 'Hjem fra jobb');
    final adHocItems = await itemService.watchItems('test-uid', adHocList.id).first;
    expect(adHocItems.map((i) => i.name), containsAll(['Brød', 'Melk', 'Bananer']));

    final bananaPrices = await priceService.searchCurrentPrices('banan');
    expect(bananaPrices, hasLength(3));
    expect(bananaPrices.first.storeChainId, 'rema1000');
  });
}
