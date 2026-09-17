/// One list item priced at a particular store.
class MatchedItem {
  MatchedItem({required this.name, required this.price});

  final String name;
  final num price;
}

/// The total cost of buying as many of a shopping list's items as we have a
/// known price for, at one store — plus exactly which items that covers,
/// since coverage varies a lot by store and source.
class StoreTotal {
  StoreTotal({
    required this.storeName,
    required this.matchedItems,
    required this.totalItemCount,
  });

  final String storeName;
  final List<MatchedItem> matchedItems;

  /// How many items the original list had in total (matched + missing).
  final int totalItemCount;

  int get matchedItemCount => matchedItems.length;

  num get total => matchedItems.fold<num>(0, (sum, item) => sum + item.price);
}
