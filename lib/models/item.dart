import 'package:cloud_firestore/cloud_firestore.dart';

/// A single item on a shopping list (e.g. "Melk", 2 stk).
class Item {
  Item({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit,
    this.note,
    this.isChecked = false,
  });

  final String id;
  final String name;
  final num quantity;

  /// Free-text unit such as "stk", "kg", "l", "pk". Null means just a count.
  final String? unit;

  /// Optional free-text note (e.g. "helst økologisk").
  final String? note;

  /// Whether the item has been put in the cart / bought.
  final bool isChecked;

  factory Item.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Item(
      id: doc.id,
      name: data['name'] as String,
      quantity: data['quantity'] as num? ?? 1,
      unit: data['unit'] as String?,
      note: data['note'] as String?,
      isChecked: data['isChecked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'note': note,
        'isChecked': isChecked,
      };
}
