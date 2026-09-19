import 'package:cloud_firestore/cloud_firestore.dart';

/// A specific store branch's walk order, contributed by a user who
/// physically tapped through their own list categories in the order they
/// passed them while shopping there — see `MapStoreLayoutScreen` and
/// `StoreLayoutService`. Overrides the generic aisle-order fallback
/// (`aisleRank`) for that one branch when a mapping exists for it.
class StoreLayout {
  StoreLayout({
    required this.branchId,
    required this.chainName,
    required this.categoryOrder,
    required this.updatedAt,
  });

  final String branchId;
  final String chainName;

  /// Category names in the order a contributor walked past them. Not
  /// guaranteed to cover every category this list uses — a category never
  /// seen here sorts after every one that was (see [rankOf]).
  final List<String> categoryOrder;
  final DateTime updatedAt;

  /// Sort key for [categoryName] within this specific branch's mapped
  /// layout — same "unknown sorts last" convention as the generic
  /// aisleRank fallback, so a category this mapping never saw doesn't
  /// jump to the front of the list.
  int rankOf(String categoryName) {
    final index = categoryOrder.indexWhere((c) => c.toLowerCase() == categoryName.toLowerCase());
    return index == -1 ? categoryOrder.length : index;
  }

  factory StoreLayout.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return StoreLayout(
      branchId: doc.id,
      chainName: data['chainName'] as String,
      categoryOrder: (data['categoryOrder'] as List<dynamic>).cast<String>(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'chainName': chainName,
        'categoryOrder': categoryOrder,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
