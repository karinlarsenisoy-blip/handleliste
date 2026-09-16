import 'package:cloud_firestore/cloud_firestore.dart';

/// A grouping within a shopping list (e.g. "Meieri", "Frukt & grønt"),
/// typically mirroring the aisles of the store the list is used in.
class Category {
  Category({required this.id, required this.name, this.order = 0});

  final String id;
  final String name;
  final int order;

  factory Category.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Category(
      id: doc.id,
      name: data['name'] as String,
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'order': order};
}
