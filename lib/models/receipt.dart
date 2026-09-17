import 'package:cloud_firestore/cloud_firestore.dart';

import 'receipt_item.dart';

/// How this receipt's raw text was captured, kept for troubleshooting parsing
/// quality per source — not shown prominently in the UI.
enum ReceiptSource { photo, pastedText, manual }

class Receipt {
  Receipt({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.purchasedAt,
    required this.source,
    required this.items,
    this.rawText,
  });

  final String id;
  final String storeId;
  final String storeName;
  final DateTime purchasedAt;
  final ReceiptSource source;
  final List<ReceiptItem> items;

  /// The unedited OCR/pasted text this receipt was parsed from, kept so a
  /// misparse can be diagnosed or re-parsed later without asking the user
  /// to redo the capture.
  final String? rawText;

  num get total => items.fold<num>(0, (accumulated, item) => accumulated + item.price);

  factory Receipt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return Receipt(
      id: doc.id,
      storeId: data['storeId'] as String,
      storeName: data['storeName'] as String,
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      source: ReceiptSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => ReceiptSource.manual,
      ),
      items: rawItems.map((e) => ReceiptItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      rawText: data['rawText'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'storeName': storeName,
        'purchasedAt': Timestamp.fromDate(purchasedAt),
        'source': source.name,
        'items': items.map((i) => i.toMap()).toList(),
        'rawText': rawText,
      };
}
