/// The total cost of buying as many of a shopping list's items as we have a
/// known price for, at one store — plus how many of the list's items that
/// total actually covers, since coverage varies a lot by store and source.
class StoreTotal {
  StoreTotal({
    required this.storeName,
    required this.total,
    required this.matchedItemCount,
    required this.totalItemCount,
  });

  final String storeName;
  final num total;
  final int matchedItemCount;
  final int totalItemCount;
}
