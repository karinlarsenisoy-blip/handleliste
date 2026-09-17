/// A single purchased line item parsed from a receipt (photo OCR or pasted
/// text) — always reviewed/correctable by the user before a receipt is saved.
class ReceiptItem {
  ReceiptItem({required this.name, required this.price, this.quantity = 1});

  final String name;

  /// Total price for this line (not unit price).
  final num price;
  final num quantity;

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory ReceiptItem.fromMap(Map<String, dynamic> map) => ReceiptItem(
        name: map['name'] as String,
        price: map['price'] as num,
        quantity: map['quantity'] as num? ?? 1,
      );
}
