import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  AccountService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _authOverride = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _authOverride;

  // Resolved lazily so tests that only exercise deleteAllUserData never need
  // a real FirebaseAuth instance (which requires Firebase.initializeApp()).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Recursively deletes every list/item belonging to [uid]. Kept separate
  /// from [deleteAccount] so the Firestore-only part can be tested with a
  /// fake Firestore instance, without needing a real Auth user.
  Future<void> deleteAllUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final listsSnapshot = await userRef.collection('lists').get();

    final refsToDelete = <DocumentReference>[];
    for (final listDoc in listsSnapshot.docs) {
      final itemsSnapshot = await listDoc.reference.collection('items').get();
      refsToDelete.addAll(itemsSnapshot.docs.map((d) => d.reference));
      refsToDelete.add(listDoc.reference);
    }

    // Firestore batches are capped at 500 writes, so chunk defensively.
    for (var i = 0; i < refsToDelete.length; i += 400) {
      final batch = _firestore.batch();
      for (final ref in refsToDelete.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Deletes all of the signed-in user's data, then their Auth account itself.
  /// May throw a [FirebaseAuthException] with code `requires-recent-login` —
  /// the caller should re-authenticate the user and call this again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await deleteAllUserData(user.uid);
    await user.delete();
  }
}
