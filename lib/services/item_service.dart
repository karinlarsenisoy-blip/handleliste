import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

class ItemService {
  ItemService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid, String listId, String categoryId) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('lists')
          .doc(listId)
          .collection('categories')
          .doc(categoryId)
          .collection('items');

  Stream<List<Item>> watchItems(String uid, String listId, String categoryId) {
    return _itemsRef(uid, listId, categoryId).orderBy('createdAt').snapshots().map(
          (snapshot) => snapshot.docs.map(Item.fromFirestore).toList(),
        );
  }

  Future<void> addItem(
    String uid,
    String listId,
    String categoryId,
    String name, {
    num quantity = 1,
    String? unit,
  }) {
    return _itemsRef(uid, listId, categoryId).add({
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': null,
      'isChecked': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleItem(String uid, String listId, String categoryId, Item item) {
    return _itemsRef(uid, listId, categoryId).doc(item.id).update({'isChecked': !item.isChecked});
  }

  Future<void> updateItem(
    String uid,
    String listId,
    String categoryId,
    Item item, {
    required String name,
    required num quantity,
    required String? unit,
    required String? note,
  }) {
    return _itemsRef(uid, listId, categoryId).doc(item.id).update({
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': note,
    });
  }

  /// Deletes the item and returns its raw data, so it can be restored via [restoreItem].
  Future<Map<String, dynamic>> deleteItem(String uid, String listId, String categoryId, Item item) async {
    final doc = await _itemsRef(uid, listId, categoryId).doc(item.id).get();
    final data = doc.data()!;
    await _itemsRef(uid, listId, categoryId).doc(item.id).delete();
    return data;
  }

  Future<void> restoreItem(
    String uid,
    String listId,
    String categoryId,
    String itemId,
    Map<String, dynamic> data,
  ) {
    return _itemsRef(uid, listId, categoryId).doc(itemId).set(data);
  }
}
