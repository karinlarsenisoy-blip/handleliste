import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handleliste_app/services/store_layout_service.dart';

void main() {
  group('StoreLayoutService', () {
    test('getLayout returns null for a branch nobody has mapped', () async {
      final firestore = FakeFirebaseFirestore();
      final service = StoreLayoutService(firestore: firestore);

      expect(await service.getLayout('osm-1'), isNull);
    });

    test('saveLayout then getLayout round-trips the category order', () async {
      final firestore = FakeFirebaseFirestore();
      final service = StoreLayoutService(firestore: firestore);

      await service.saveLayout('osm-1', 'Kiwi', ['Frukt & grønt', 'Meieri', 'Frost']);
      final layout = await service.getLayout('osm-1');

      expect(layout, isNotNull);
      expect(layout!.chainName, 'Kiwi');
      expect(layout.categoryOrder, ['Frukt & grønt', 'Meieri', 'Frost']);
    });

    test('rankOf reflects the mapped order, unknown categories sort last', () async {
      final firestore = FakeFirebaseFirestore();
      final service = StoreLayoutService(firestore: firestore);
      await service.saveLayout('osm-1', 'Kiwi', ['Meieri', 'Frukt & grønt']);

      final layout = await service.getLayout('osm-1');

      expect(layout!.rankOf('meieri'), 0);
      expect(layout.rankOf('Frukt & grønt'), 1);
      expect(layout.rankOf('Diverse'), 2);
    });

    test('a later save overwrites the earlier mapping for the same branch', () async {
      final firestore = FakeFirebaseFirestore();
      final service = StoreLayoutService(firestore: firestore);

      await service.saveLayout('osm-1', 'Kiwi', ['Meieri', 'Frost']);
      await service.saveLayout('osm-1', 'Kiwi', ['Frukt & grønt', 'Meieri', 'Frost']);

      final layout = await service.getLayout('osm-1');
      expect(layout!.categoryOrder, ['Frukt & grønt', 'Meieri', 'Frost']);
    });

    test('getLayouts looks up several branches at once, omitting unmapped ones', () async {
      final firestore = FakeFirebaseFirestore();
      final service = StoreLayoutService(firestore: firestore);
      await service.saveLayout('osm-1', 'Kiwi', ['Meieri']);
      await service.saveLayout('osm-2', 'Rema 1000', ['Frost']);

      final layouts = await service.getLayouts(['osm-1', 'osm-2', 'osm-3']);

      expect(layouts.keys, containsAll(['osm-1', 'osm-2']));
      expect(layouts.containsKey('osm-3'), isFalse);
      expect(layouts['osm-1']!.chainName, 'Kiwi');
      expect(layouts['osm-2']!.chainName, 'Rema 1000');
    });
  });
}
