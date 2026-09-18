import '../models/favorite_item.dart';
import 'receipt_service.dart';

/// Turns receipt history into a "what do you actually keep buying" ranking
/// — the motivation being that scanning receipts should visibly pay off for
/// the user, not just feed the shared price database.
class FavoritesService {
  FavoritesService({ReceiptService? receiptService}) : _receiptService = receiptService ?? ReceiptService();

  final ReceiptService _receiptService;

  /// The user's most-purchased items, ranked by how many distinct receipts
  /// they appeared on (not summed quantity — one big stock-up trip
  /// shouldn't outweigh five separate ones). Items seen fewer than
  /// [minPurchases] times are left out: a favorite should mean a repeat,
  /// not a one-off.
  Future<List<FavoriteItem>> mostPurchased(
    String uid, {
    int limit = 10,
    int minPurchases = 2,
  }) async {
    final receipts = await _receiptService.watchReceipts(uid).first;

    final purchaseCountByKey = <String, int>{};
    final displayNameByKey = <String, String>{};
    final lastPurchasedAtByKey = <String, DateTime>{};
    final lastUnitPriceByKey = <String, num>{};

    for (final receipt in receipts) {
      final namesOnThisReceipt = <String>{};
      for (final item in receipt.items) {
        final key = item.name.trim().toLowerCase();
        if (key.isEmpty) continue;
        namesOnThisReceipt.add(key);

        final knownDate = lastPurchasedAtByKey[key];
        if (knownDate == null || receipt.purchasedAt.isAfter(knownDate)) {
          lastPurchasedAtByKey[key] = receipt.purchasedAt;
          displayNameByKey[key] = item.name.trim();
          lastUnitPriceByKey[key] = item.quantity == 0 ? item.price : item.price / item.quantity;
        }
      }
      for (final key in namesOnThisReceipt) {
        purchaseCountByKey[key] = (purchaseCountByKey[key] ?? 0) + 1;
      }
    }

    final favorites = purchaseCountByKey.entries
        .where((entry) => entry.value >= minPurchases)
        .map((entry) => FavoriteItem(
              name: displayNameByKey[entry.key]!,
              purchaseCount: entry.value,
              lastPurchasedAt: lastPurchasedAtByKey[entry.key]!,
              lastPrice: lastUnitPriceByKey[entry.key]!,
            ))
        .toList()
      ..sort((a, b) {
        final byCount = b.purchaseCount.compareTo(a.purchaseCount);
        if (byCount != 0) return byCount;
        return b.lastPurchasedAt.compareTo(a.lastPurchasedAt);
      });

    return favorites.take(limit).toList();
  }
}
