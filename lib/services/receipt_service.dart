import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/receipt.dart';

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
