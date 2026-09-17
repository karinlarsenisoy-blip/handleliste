/// One list item, assigned to whichever store has the lowest known price
/// for it.
class ItemAssignment {
  ItemAssignment({required this.itemName, required this.storeName, required this.price});

  final String itemName;
  final String storeName;
  final num price;
}

/// The cheapest possible way to buy a whole shopping list, split across as
/// many stores as it takes — each item assigned to wherever it's
/// individually cheapest. This is the mathematically optimal split for pure
/// cost (buying each item where it costs least can never cost more than any
/// single-store or partial-split alternative); it doesn't yet weigh that
/// against how many stores/how much travel that split requires.
class ShoppingSplit {
  ShoppingSplit({required this.assignments, required this.unmatchedItems});

  final List<ItemAssignment> assignments;

  /// Items with no known price anywhere.
  final List<String> unmatchedItems;

  num get total => assignments.fold<num>(0, (sum, item) => sum + item.price);

  Map<String, List<ItemAssignment>> get assignmentsByStore {
    final map = <String, List<ItemAssignment>>{};
    for (final assignment in assignments) {
      (map[assignment.storeName] ??= []).add(assignment);
    }
    return map;
  }
}
