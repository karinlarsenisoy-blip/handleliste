/// A known product suggested while typing an item name — sourced from
/// Kassalapp (kassal.app), a Norwegian grocery price/product API, not our
/// own crowdsourced price database. Purely for helping the user pick a
/// specific product instead of typing free text; the price/store it comes
/// with is a bonus, not something we've verified ourselves.
class ProductSuggestion {
  ProductSuggestion({
    required this.name,
    this.brand,
    this.imageUrl,
    this.quantity,
    this.price,
    this.storeName,
  });

  final String name;
  final String? brand;
  final String? imageUrl;

  /// Pack size, e.g. "1000 g" — often already part of [name] too.
  final String? quantity;

  /// Kassalapp's last-seen price for this listing, if known.
  final num? price;

  /// Which store this [price] was observed at, if known.
  final String? storeName;
}
