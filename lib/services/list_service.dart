import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_list.dart';

/// Everything needed to fully restore a deleted list: its own data plus
/// every category and item that was nested under it.
class ListSnapshot {
  ListSnapshot({
    required this.listData,
    required this.categoriesData,
    required this.itemsData,
  });

  final Map<String, dynamic> listData;
  final Map<String, Map<String, dynamic>> categoriesData;
  final Map<String, Map<String, Map<String, dynamic>>> itemsData;
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
    final categoriesSnapshot = await _listsRef(uid).doc(listId).collection('categories').get();

    final categoriesData = <String, Map<String, dynamic>>{};
    final itemsData = <String, Map<String, Map<String, dynamic>>>{};
    final batch = _firestore.batch();

    for (final categoryDoc in categoriesSnapshot.docs) {
      categoriesData[categoryDoc.id] = categoryDoc.data();
      final itemsSnapshot = await categoryDoc.reference.collection('items').get();
      itemsData[categoryDoc.id] = {for (final i in itemsSnapshot.docs) i.id: i.data()};
      for (final itemDoc in itemsSnapshot.docs) {
        batch.delete(itemDoc.reference);
      }
      batch.delete(categoryDoc.reference);
    }
    batch.delete(_listsRef(uid).doc(listId));
    await batch.commit();

    return ListSnapshot(
      listData: listDoc.data()!,
      categoriesData: categoriesData,
      itemsData: itemsData,
    );
  }

  Future<void> restoreList(String uid, String listId, ListSnapshot snapshot) async {
    final batch = _firestore.batch();
    final listRef = _listsRef(uid).doc(listId);
    batch.set(listRef, snapshot.listData);
    for (final entry in snapshot.categoriesData.entries) {
      batch.set(listRef.collection('categories').doc(entry.key), entry.value);
    }
    for (final categoryEntry in snapshot.itemsData.entries) {
      final itemsRef = listRef.collection('categories').doc(categoryEntry.key).collection('items');
      for (final itemEntry in categoryEntry.value.entries) {
        batch.set(itemsRef.doc(itemEntry.key), itemEntry.value);
      }
    }
    await batch.commit();
  }
}
