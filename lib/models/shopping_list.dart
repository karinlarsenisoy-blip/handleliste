import 'package:cloud_firestore/cloud_firestore.dart';

/// A top-level "tab" (e.g. "Ukehandel", "Bursdag") that groups a set of
/// categories, each with their own items.
class ShoppingList {
  ShoppingList({required this.id, required this.name, this.order = 0});

  final String id;
  final String name;
  final int order;

  factory ShoppingList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ShoppingList(
      id: doc.id,
      name: data['name'] as String,
      order: data['order'] as int? ?? 0,
    );
  }
}
