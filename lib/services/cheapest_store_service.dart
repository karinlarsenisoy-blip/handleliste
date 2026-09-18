import '../models/cheapest_store_analysis.dart';
import '../models/shopping_split.dart';
import '../models/store.dart';
import '../models/store_total.dart';
import 'kassalapp_service.dart';
import 'price_service.dart';

/// A price is only used for "what's cheapest right now" if it was actually
/// observed within this window — third-party price data can be years out of
/// date (Kassalapp listings have ranged from same-day to 2023), and using a
/// stale price to declare a store "cheapest" would be actively misleading
/// for a feature whose whole point is up-to-date accuracy at the moment the
/// user is about to shop.
const _maxPriceAge = Duration(days: 30);

typedef _PriceEntry = ({String storeName, num price, DateTime lastObservedAt});

/// For a list of item names, works out where to buy it cheapest right now —
/// combining our own crowdsourced [PriceService] data (currently the only
/// source that can ever cover Kiwi/Rema 1000, since Kassalapp has no
/// listings for either — see project notes) with [KassalappService] for the
/// chains it does cover (Coop, SPAR, Meny, Joker, Oda). Both are re-queried
/// live on every call — nothing here is cached — but a live query is only
/// as good as how recently the underlying price was actually observed,
/// hence [_maxPriceAge].
///
/// [analyze] fetches every item's prices exactly once and derives two views
/// from that single shared dataset, so they can never disagree with each
/// other:
/// - store totals: rank single stores, for "which one store should I just
///   go to".
/// - split: the mathematically cheapest way to buy the whole list, split
///   across as many stores as it takes — each item assigned to wherever
///   it's individually cheapest. Which one is actually worth it depends on
///   how much extra travel the split costs, which this doesn't know about
///   yet (that's the route feature).
class CheapestStoreService {
  CheapestStoreService({PriceService? priceService, KassalappService? kassalappService})
      : _priceService = priceService ?? PriceService(),
        _kassalappService = kassalappService ?? KassalappService();

  final PriceService _priceService;
  final KassalappService _kassalappService;

  bool _isFresh(DateTime? observedAt) {
    if (observedAt == null) return false;
    return DateTime.now().difference(observedAt) <= _maxPriceAge;
  }

  /// Every (store, price, last-observed) triple we know of for [itemName]
  /// that's still fresh enough to trust — cheapest first isn't guaranteed
  /// here, callers decide what to do with the full set.
  Future<List<_PriceEntry>> _pricesForItem(String itemName) async {
    final results = <_PriceEntry>[];
    final seenStores = <String>{};

    final ownPrices = await _priceService.searchCurrentPrices(itemName);
    for (final price in ownPrices) {
      if (!_isFresh(price.lastObservedAt)) continue;
      final storeName = displayNameForChainId(price.storeChainId);
      if (!seenStores.add(storeName)) continue;
      results.add((storeName: storeName, price: price.price, lastObservedAt: price.lastObservedAt));
    }

    if (KassalappService.isConfigured) {
      try {
        final suggestions = await _kassalappService.search(itemName);
        for (final suggestion in suggestions) {
          final rawStoreName = suggestion.storeName;
          final price = suggestion.price;
          if (rawStoreName == null || price == null) continue;
          if (!_isFresh(suggestion.lastObservedAt)) continue;
          final storeName = canonicalStoreName(rawStoreName);
          if (!seenStores.add(storeName)) continue;
          results.add((storeName: storeName, price: price, lastObservedAt: suggestion.lastObservedAt!));
        }
      } catch (_) {
        // Kassalapp is a supplementary source — keep going with what we
        // have from our own price data if it's unavailable.
      }
    }

    return results;
  }

  /// Fetches prices for every item exactly once, then builds both the
  /// single-store ranking and the multi-store split from that same data.
  ///
  /// Every item's lookup runs concurrently — each one is an independent
  /// Firestore query plus a live Kassalapp HTTP call, so awaiting them one
  /// at a time in a loop would make a 12-item list take roughly 12x as
  /// long as it needs to for no benefit.
  Future<CheapestStoreAnalysis> analyze(List<String> itemNames) async {
    final entries = await Future.wait(
      itemNames.map((itemName) async => MapEntry(itemName, await _pricesForItem(itemName))),
    );
    final pricesByItem = Map<String, List<_PriceEntry>>.fromEntries(entries);

    return CheapestStoreAnalysis(
      storeTotals: _buildStoreTotals(itemNames, pricesByItem),
      split: _buildSplit(itemNames, pricesByItem),
    );
  }

  List<StoreTotal> _buildStoreTotals(List<String> itemNames, Map<String, List<_PriceEntry>> pricesByItem) {
    final matchedItemsByStore = <String, List<MatchedItem>>{};

    for (final itemName in itemNames) {
      for (final entry in pricesByItem[itemName] ?? const <_PriceEntry>[]) {
        (matchedItemsByStore[entry.storeName] ??= []).add(
          MatchedItem(name: itemName, price: entry.price, lastObservedAt: entry.lastObservedAt),
        );
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

  ShoppingSplit _buildSplit(List<String> itemNames, Map<String, List<_PriceEntry>> pricesByItem) {
    final assignments = <ItemAssignment>[];
    final unmatched = <String>[];

    for (final itemName in itemNames) {
      final prices = pricesByItem[itemName] ?? const <_PriceEntry>[];
      if (prices.isEmpty) {
        unmatched.add(itemName);
        continue;
      }

      var cheapest = prices.first;
      for (final entry in prices.skip(1)) {
        if (entry.price < cheapest.price) cheapest = entry;
      }
      assignments.add(ItemAssignment(
        itemName: itemName,
        storeName: cheapest.storeName,
        price: cheapest.price,
        lastObservedAt: cheapest.lastObservedAt,
      ));
    }

    return ShoppingSplit(assignments: assignments, unmatchedItems: unmatched);
  }
}
