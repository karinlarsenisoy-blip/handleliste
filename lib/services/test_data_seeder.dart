import '../models/price_observation.dart';
import 'category_service.dart';
import 'item_service.dart';
import 'list_service.dart';
import 'price_service.dart';

/// Dev/demo helper: populates a couple of realistic shopping lists for the
/// signed-in user, plus a handful of price observations across a few chains
/// so the shared price database has something to compare against. Not part
/// of the real product — triggered manually from the account menu while
/// we're building and testing the price-comparison/route features.
class TestDataSeeder {
  TestDataSeeder({
    ListService? listService,
    CategoryService? categoryService,
    ItemService? itemService,
    PriceService? priceService,
  })  : _listService = listService ?? ListService(),
        _categoryService = categoryService ?? CategoryService(),
        _itemService = itemService ?? ItemService(),
        _priceService = priceService ?? PriceService();

  final ListService _listService;
  final CategoryService _categoryService;
  final ItemService _itemService;
  final PriceService _priceService;

  Future<void> seedAll(String uid) async {
    await _seedWeeklyList(uid);
    await _seedAdHocList(uid);
    await _seedPriceObservations();
  }

  Future<void> _seedWeeklyList(String uid) async {
    await _listService.addList(uid, 'Ukehandel');
    final list = (await _listService.watchLists(uid).first)
        .firstWhere((l) => l.name == 'Ukehandel');

    final groceries = {
      'Meieri': ['Melk', 'Ost', 'Yoghurt', 'Smør'],
      'Frukt & grønt': ['Bananer', 'Epler', 'Poteter', 'Løk'],
      'Kjøtt & fisk': ['Kjøttdeig', 'Kyllingfilet'],
      'Non-food': ['Oppvasktabletter', 'Toalettpapir'],
    };

    for (final entry in groceries.entries) {
      await _categoryService.addCategory(uid, list.id, entry.key);
      final category = (await _categoryService.watchCategories(uid, list.id).first)
          .firstWhere((c) => c.name == entry.key);
      for (final itemName in entry.value) {
        await _itemService.addItem(uid, list.id, category.id, itemName);
      }
    }
  }

  Future<void> _seedAdHocList(String uid) async {
    await _listService.addList(uid, 'Hjem fra jobb');
    final list = (await _listService.watchLists(uid).first)
        .firstWhere((l) => l.name == 'Hjem fra jobb');

    await _categoryService.addCategory(uid, list.id, 'Diverse');
    final category = (await _categoryService.watchCategories(uid, list.id).first)
        .firstWhere((c) => c.name == 'Diverse');

    for (final itemName in ['Brød', 'Melk', 'Bananer']) {
      await _itemService.addItem(uid, list.id, category.id, itemName);
    }
  }

  Future<void> _seedPriceObservations() async {
    final now = DateTime.now();
    final prices = <(String chain, String item, num price)>[
      ('kiwi', 'Bananer', 24.90),
      ('rema1000', 'Bananer', 22.90),
      ('coop_extra', 'Bananer', 26.50),
      ('kiwi', 'Melk', 24.90),
      ('rema1000', 'Melk', 23.90),
      ('coop_extra', 'Melk', 24.50),
      ('kiwi', 'Brød', 32.90),
      ('rema1000', 'Brød', 29.90),
      ('coop_extra', 'Brød', 31.90),
      ('kiwi', 'Egg', 52.90),
      ('rema1000', 'Egg', 49.90),
      ('coop_extra', 'Egg', 54.90),
      ('kiwi', 'Kjøttdeig', 79.90),
      ('rema1000', 'Kjøttdeig', 74.90),
      ('coop_extra', 'Kjøttdeig', 82.90),
      ('kiwi', 'Ost', 89.90),
      ('rema1000', 'Ost', 85.90),
      ('coop_extra', 'Ost', 91.90),
    ];

    for (final (chain, item, price) in prices) {
      await _priceService.contributeObservation(PriceObservation(
        storeChainId: chain,
        itemName: item,
        price: price,
        observedAt: now,
      ));
    }
  }
}
