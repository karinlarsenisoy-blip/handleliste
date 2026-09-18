import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/receipt.dart';
import '../models/receipt_item.dart';

class ReceiptService {
  ReceiptService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _receiptsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('receipts');

  Stream<List<Receipt>> watchReceipts(String uid) {
    return _receiptsRef(uid).orderBy('purchasedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(Receipt.fromFirestore).toList(),
        );
  }

  Future<void> addReceipt(String uid, Receipt receipt) {
    return _receiptsRef(uid).add(receipt.toMap());
  }

  /// True if [candidate] looks like the same shopping trip as a receipt
  /// this user already saved — same store, same calendar day, and the
  /// exact same set of items/prices/quantities. Guards against an
  /// accidental double-save (or re-importing the same photo/text) silently
  /// counting one trip's prices twice, both in the shared price database
  /// and in Favorites' purchase counts.
  Future<bool> isDuplicateOf(String uid, Receipt candidate) async {
    final existing = await watchReceipts(uid).first;
    return existing.any((saved) => _isSameTrip(saved, candidate));
  }

  bool _isSameTrip(Receipt a, Receipt b) {
    if (a.storeId != b.storeId) return false;
    if (!_isSameDay(a.purchasedAt, b.purchasedAt)) return false;
    return _sameItems(a.items, b.items);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameItems(List<ReceiptItem> a, List<ReceiptItem> b) {
    if (a.length != b.length) return false;
    String keyOf(ReceiptItem item) => '${item.name.trim().toLowerCase()}|${item.price}|${item.quantity}';
    final aKeys = a.map(keyOf).toList()..sort();
    final bKeys = b.map(keyOf).toList()..sort();
    for (var i = 0; i < aKeys.length; i++) {
      if (aKeys[i] != bKeys[i]) return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> deleteReceipt(String uid, String receiptId) async {
    final doc = await _receiptsRef(uid).doc(receiptId).get();
    final data = doc.data()!;
    await _receiptsRef(uid).doc(receiptId).delete();
    return data;
  }

  Future<void> restoreReceipt(String uid, String receiptId, Map<String, dynamic> data) {
    return _receiptsRef(uid).doc(receiptId).set(data);
  }
}
