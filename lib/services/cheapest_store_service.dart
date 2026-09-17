import '../models/store.dart';
import '../models/store_total.dart';
import 'kassalapp_service.dart';
import 'price_service.dart';

/// For a list of item names, works out which store is cheapest overall —
/// combining our own crowdsourced [PriceService] data (currently the only
/// source that can ever cover Kiwi/Rema 1000, since Kassalapp has no
/// listings for either — see project notes) with [KassalappService] for the
/// chains it does cover (Coop, SPAR, Meny, Joker, Oda).
///
/// v1: ranks single stores by total price across whatever items we have a
/// price for there. It deliberately does NOT yet try to split the list
/// across two stores for a lower combined total — that's a real
/// optimization problem worth its own round once this simpler version
/// proves useful.
class CheapestStoreService {
  CheapestStoreService({PriceService? priceService, KassalappService? kassalappService})
      : _priceService = priceService ?? PriceService(),
        _kassalappService = kassalappService ?? KassalappService();

  final PriceService _priceService;
  final KassalappService _kassalappService;

  Future<List<StoreTotal>> findCheapestStores(List<String> itemNames) async {
    final totals = <String, num>{};
    final matchedCounts = <String, int>{};

    for (final itemName in itemNames) {
      final storesMatchedForThisItem = <String>{};

      final ownPrices = await _priceService.searchCurrentPrices(itemName);
      for (final price in ownPrices) {
        final storeName = displayNameForChainId(price.storeChainId);
        if (!storesMatchedForThisItem.add(storeName)) continue;
        totals[storeName] = (totals[storeName] ?? 0) + price.price;
        matchedCounts[storeName] = (matchedCounts[storeName] ?? 0) + 1;
      }

      if (KassalappService.isConfigured) {
        try {
          final suggestions = await _kassalappService.search(itemName);
          for (final suggestion in suggestions) {
            final rawStoreName = suggestion.storeName;
            final price = suggestion.price;
            if (rawStoreName == null || price == null) continue;
            final storeName = canonicalStoreName(rawStoreName);
            if (!storesMatchedForThisItem.add(storeName)) continue;
            totals[storeName] = (totals[storeName] ?? 0) + price;
            matchedCounts[storeName] = (matchedCounts[storeName] ?? 0) + 1;
          }
        } catch (_) {
          // Kassalapp is a supplementary source — keep going with what we
          // have from our own price data if it's unavailable.
        }
      }
    }

    final results = totals.entries
        .map((entry) => StoreTotal(
              storeName: entry.key,
              total: entry.value,
              matchedItemCount: matchedCounts[entry.key] ?? 0,
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
}
