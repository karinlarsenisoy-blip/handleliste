import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_list.dart';

/// Everything needed to fully restore a deleted list: its own data plus
/// every item that lived directly under it (no category/folder level, see
/// ItemService's doc for why).
class ListSnapshot {
  ListSnapshot({required this.listData, required this.itemsData});

  final Map<String, dynamic> listData;
  final Map<String, Map<String, dynamic>> itemsData;
}

class ListService {
  ListService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _listsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('lists');

  Stream<List<ShoppingList>> watchLists(String uid) {
    return _listsRef(uid).orderBy('order').snapshots().map(
          (snapshot) => snapshot.docs.map(ShoppingList.fromFirestore).toList(),
        );
  }

  Future<void> addList(String uid, String name) {
    return _listsRef(uid).add({
      'name': name,
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameList(String uid, String listId, String newName) {
    return _listsRef(uid).doc(listId).update({'name': newName});
  }

  Future<ListSnapshot> deleteList(String uid, String listId) async {
    final listDoc = await _listsRef(uid).doc(listId).get();
    final itemsSnapshot = await _listsRef(uid).doc(listId).collection('items').get();

    final itemsData = {for (final i in itemsSnapshot.docs) i.id: i.data()};
    final batch = _firestore.batch();
    for (final itemDoc in itemsSnapshot.docs) {
      batch.delete(itemDoc.reference);
    }
    batch.delete(_listsRef(uid).doc(listId));
    await batch.commit();

    return ListSnapshot(listData: listDoc.data()!, itemsData: itemsData);
  }

  Future<void> restoreList(String uid, String listId, ListSnapshot snapshot) async {
    final batch = _firestore.batch();
    final listRef = _listsRef(uid).doc(listId);
    batch.set(listRef, snapshot.listData);
    for (final entry in snapshot.itemsData.entries) {
      batch.set(listRef.collection('items').doc(entry.key), entry.value);
    }
    await batch.commit();
  }
}
