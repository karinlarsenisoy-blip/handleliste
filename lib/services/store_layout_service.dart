import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_layout.dart';

/// Crowdsourced per-branch store layouts — a shared, top-level collection
/// (not scoped to one user) since a store's actual layout is a fact about
/// the physical store, not about whoever mapped it. Same "shared, anonymous
/// contribution" shape as [PriceService]'s price data.
class StoreLayoutService {
  StoreLayoutService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _layoutsRef => _firestore.collection('storeLayouts');

  /// The mapped layout for [branchId], or null if nobody has mapped it yet.
  Future<StoreLayout?> getLayout(String branchId) async {
    final doc = await _layoutsRef.doc(branchId).get();
    if (!doc.exists) return null;
    return StoreLayout.fromFirestore(doc);
  }

  /// Looks up every id in [branchIds] at once (in parallel) — for checking
  /// several nearby branches without waiting on one round trip per branch.
  /// Branches with no mapping yet are simply absent from the result.
  Future<Map<String, StoreLayout>> getLayouts(Iterable<String> branchIds) async {
    final entries = await Future.wait(
      branchIds.toSet().map((id) async {
        final layout = await getLayout(id);
        return layout == null ? null : MapEntry(id, layout);
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<String, StoreLayout>>());
  }

  /// Saves [categoryOrder] as the layout for [branchId]. A later
  /// contribution simply overwrites an earlier one — the same "latest wins"
  /// convention [PriceService] uses for prices, since a store's actual
  /// layout can change too (renovations, reorganizing shelves) and there's
  /// no reliable way yet to tell a correction from a mistake.
  Future<void> saveLayout(String branchId, String chainName, List<String> categoryOrder) {
    return _layoutsRef.doc(branchId).set(
      StoreLayout(
        branchId: branchId,
        chainName: chainName,
        categoryOrder: categoryOrder,
        updatedAt: DateTime.now(),
      ).toMap(),
    );
  }
}
