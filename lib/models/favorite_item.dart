/// A shopping-list item name ranked by how often it's actually shown up on
/// the user's *receipts* — not how often it's been typed into a list. That
/// distinction is the whole point: a list item can be added and never
/// bought, but a receipt line means it was actually purchased.
class FavoriteItem {
  FavoriteItem({
    required this.name,
    required this.purchaseCount,
    required this.lastPurchasedAt,
    required this.lastPrice,
  });

  final String name;

  /// Number of distinct receipts this item appeared on — a trip-frequency
  /// count, not a summed quantity, so one large stock-up receipt can't make
  /// an item look far more "favorite" than it really is.
  final int purchaseCount;

  final DateTime lastPurchasedAt;

  /// Per-unit price from the most recent receipt it appeared on — just a
  /// reference point, not a live price (see PriceService/CheapestStoreService
  /// for that).
  final num lastPrice;
}
