import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';

/// Items live directly under a list — no category/folder level. Earlier
/// versions nested items under `categories/{categoryId}`, copying the To-do
/// app's structure; that was deliberately dropped (see project notes) so
/// Handleliste doesn't read as "make your own folders" the way a generic
/// task app does. Which aisle an item belongs to (for sorting, see
/// aisleRank) is now inferred from the item's own name instead of a
/// user-authored category name.
class ItemService {
  ItemService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid, String listId) =>
      _firestore.collection('users').doc(uid).collection('lists').doc(listId).collection('items');

  Stream<List<Item>> watchItems(String uid, String listId) {
    return _itemsRef(uid, listId).orderBy('createdAt').snapshots().map(
          (snapshot) => snapshot.docs.map(Item.fromFirestore).toList(),
        );
  }

  Future<void> addItem(
    String uid,
    String listId,
    String name, {
    num quantity = 1,
    String? unit,
    String? imageUrl,
  }) {
    return _itemsRef(uid, listId).add({
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': null,
      'isChecked': false,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleItem(String uid, String listId, Item item) {
    return _itemsRef(uid, listId).doc(item.id).update({'isChecked': !item.isChecked});
  }

  Future<void> updateItem(
    String uid,
    String listId,
    Item item, {
    required String name,
    required num quantity,
    required String? unit,
    required String? note,
  }) {
    return _itemsRef(uid, listId).doc(item.id).update({
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': note,
    });
  }

  /// Deletes the item and returns its raw data, so it can be restored via [restoreItem].
  Future<Map<String, dynamic>> deleteItem(String uid, String listId, Item item) async {
    final doc = await _itemsRef(uid, listId).doc(item.id).get();
    final data = doc.data()!;
    await _itemsRef(uid, listId).doc(item.id).delete();
    return data;
  }

  Future<void> restoreItem(String uid, String listId, String itemId, Map<String, dynamic> data) {
    return _itemsRef(uid, listId).doc(itemId).set(data);
  }
}
