import '../models/shopping_split.dart';
import '../models/store.dart';
import '../models/store_total.dart';
import 'kassalapp_service.dart';
import 'price_service.dart';

/// For a list of item names, works out where to buy it cheapest —
/// combining our own crowdsourced [PriceService] data (currently the only
/// source that can ever cover Kiwi/Rema 1000, since Kassalapp has no
/// listings for either — see project notes) with [KassalappService] for the
/// chains it does cover (Coop, SPAR, Meny, Joker, Oda).
///
/// Two views of the same underlying per-item price lookups:
/// - [findCheapestStores]: rank single stores, for "which one store should
///   I just go to".
/// - [findCheapestSplit]: the mathematically cheapest way to buy the whole
///   list, split across as many stores as it takes — each item assigned to
///   wherever it's individually cheapest. Which one is actually worth it
///   depends on how much extra travel the split costs, which this doesn't
///   know about yet (that's the route feature).
class CheapestStoreService {
  CheapestStoreService({PriceService? priceService, KassalappService? kassalappService})
      : _priceService = priceService ?? PriceService(),
        _kassalappService = kassalappService ?? KassalappService();

  final PriceService _priceService;
  final KassalappService _kassalappService;

  /// Every (store, price) pair we know of for [itemName], cheapest first
  /// isn't guaranteed here — callers decide what to do with the full set.
  Future<List<({String storeName, num price})>> _pricesForItem(String itemName) async {
    final results = <({String storeName, num price})>[];
    final seenStores = <String>{};

    final ownPrices = await _priceService.searchCurrentPrices(itemName);
    for (final price in ownPrices) {
      final storeName = displayNameForChainId(price.storeChainId);
      if (!seenStores.add(storeName)) continue;
      results.add((storeName: storeName, price: price.price));
    }

    if (KassalappService.isConfigured) {
      try {
        final suggestions = await _kassalappService.search(itemName);
        for (final suggestion in suggestions) {
          final rawStoreName = suggestion.storeName;
          final price = suggestion.price;
          if (rawStoreName == null || price == null) continue;
          final storeName = canonicalStoreName(rawStoreName);
          if (!seenStores.add(storeName)) continue;
          results.add((storeName: storeName, price: price));
        }
      } catch (_) {
        // Kassalapp is a supplementary source — keep going with what we
        // have from our own price data if it's unavailable.
      }
    }

    return results;
  }

  Future<List<StoreTotal>> findCheapestStores(List<String> itemNames) async {
    final matchedItemsByStore = <String, List<MatchedItem>>{};

    for (final itemName in itemNames) {
      for (final entry in await _pricesForItem(itemName)) {
        (matchedItemsByStore[entry.storeName] ??= [])
            .add(MatchedItem(name: itemName, price: entry.price));
      }
    }

    final results = matchedItemsByStore.entries
        .map((entry) => StoreTotal(
              storeName: entry.key,
              matchedItems: entry.value,
              totalItemCount: itemNames.length,
            ))
        .toList();

    // Coverage first, price second: a store that only has one cheap item
    // priced shouldn't outrank one that covers the whole list, even if its
    // raw total happens to be lower.
    results.sort((a, b) {
      final byCoverage = b.matchedItemCount.compareTo(a.matchedItemCount);
      if (byCoverage != 0) return byCoverage;
      return a.total.compareTo(b.total);
    });
    return results;
  }

  Future<ShoppingSplit> findCheapestSplit(List<String> itemNames) async {
    final assignments = <ItemAssignment>[];
    final unmatched = <String>[];

    for (final itemName in itemNames) {
      final prices = await _pricesForItem(itemName);
      if (prices.isEmpty) {
        unmatched.add(itemName);
        continue;
      }

      var cheapest = prices.first;
      for (final entry in prices.skip(1)) {
        if (entry.price < cheapest.price) cheapest = entry;
      }
      assignments.add(ItemAssignment(itemName: itemName, storeName: cheapest.storeName, price: cheapest.price));
    }

    return ShoppingSplit(assignments: assignments, unmatchedItems: unmatched);
  }
}
