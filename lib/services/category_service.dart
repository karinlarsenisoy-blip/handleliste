import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

/// Everything needed to fully restore a deleted category: its own data plus
/// every item that was nested under it.
class CategorySnapshot {
  CategorySnapshot({required this.categoryData, required this.itemsData});

  final Map<String, dynamic> categoryData;
  final Map<String, Map<String, dynamic>> itemsData;
}

class CategoryService {
  CategoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String uid, String listId) => _firestore
      .collection('users')
      .doc(uid)
      .collection('lists')
      .doc(listId)
      .collection('categories');

  Stream<List<Category>> watchCategories(String uid, String listId) {
    return _categoriesRef(uid, listId).orderBy('order').snapshots().map(
          (snapshot) => snapshot.docs.map(Category.fromFirestore).toList(),
        );
  }

  Future<void> addCategory(String uid, String listId, String name) {
    return _categoriesRef(uid, listId).add({
      'name': name,
      // New categories always sort after any existing (small, normalized)
      // order values, since a millisecond timestamp is much larger than them.
      'order': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameCategory(String uid, String listId, String categoryId, String newName) {
    return _categoriesRef(uid, listId).doc(categoryId).update({'name': newName});
  }

  /// Persists a new category order after the user drags one into place.
  /// Rewrites every category's `order` field to its index in [orderedCategories].
  Future<void> reorderCategories(String uid, String listId, List<Category> orderedCategories) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedCategories.length; i++) {
      batch.update(_categoriesRef(uid, listId).doc(orderedCategories[i].id), {'order': i});
    }
    await batch.commit();
  }

  Future<CategorySnapshot> deleteCategory(String uid, String listId, String categoryId) async {
    final categoryDoc = await _categoriesRef(uid, listId).doc(categoryId).get();
    final itemsSnapshot = await _categoriesRef(uid, listId).doc(categoryId).collection('items').get();

    final batch = _firestore.batch();
    for (final doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_categoriesRef(uid, listId).doc(categoryId));
    await batch.commit();

    return CategorySnapshot(
      categoryData: categoryDoc.data()!,
      itemsData: {for (final d in itemsSnapshot.docs) d.id: d.data()},
    );
  }

  Future<void> restoreCategory(
    String uid,
    String listId,
    String categoryId,
    CategorySnapshot snapshot,
  ) async {
    final batch = _firestore.batch();
    final categoryRef = _categoriesRef(uid, listId).doc(categoryId);
    batch.set(categoryRef, snapshot.categoryData);
    for (final entry in snapshot.itemsData.entries) {
      batch.set(categoryRef.collection('items').doc(entry.key), entry.value);
    }
    await batch.commit();
  }
}
