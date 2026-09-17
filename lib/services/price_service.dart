import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/current_price.dart';
import '../models/price_observation.dart';

/// The shared, cross-user price database — anonymous by design (no uid is
/// ever stored here). Every receipt line a user opts to contribute becomes
/// one append-only [PriceObservation], plus an upsert of the matching
/// [CurrentPrice] row so lookups stay fast as the history grows.
///
/// v1 has no per-chain product matching (see [normalizeItemName]) and no
/// server-side abuse protection beyond Firestore rules field validation —
/// both are fine at small scale, but worth revisiting (the latter likely via
/// a Cloud Function once the project is on a billing plan) once real
/// third-party users start contributing.
class PriceService {
  PriceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _observationsRef =>
      _firestore.collection('priceObservations');

  CollectionReference<Map<String, dynamic>> get _currentPricesRef =>
      _firestore.collection('currentPrices');

  String _currentPriceDocId(String storeChainId, String itemNameNormalized) {
    final safeName = itemNameNormalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$storeChainId-$safeName';
  }

  /// Contributes one anonymous price observation and refreshes the
  /// corresponding "current price" row. Safe to call once per receipt line
  /// the user opts to share.
  Future<void> contributeObservation(PriceObservation observation) async {
    await _observationsRef.add(observation.toMap());

    final docRef = _currentPricesRef.doc(
      _currentPriceDocId(observation.storeChainId, observation.itemNameNormalized),
    );

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      final previousCount = existing.data()?['sampleCount'] as int? ?? 0;
      transaction.set(docRef, {
        'storeChainId': observation.storeChainId,
        'itemName': observation.itemName,
        'itemNameNormalized': observation.itemNameNormalized,
        'price': observation.price,
        'lastObservedAt': Timestamp.fromDate(observation.observedAt),
        'sampleCount': previousCount + 1,
      });
    });
  }

  /// Every chain's current price for items whose normalized name starts
  /// with [query] (e.g. "bana" matches "bananer"), cheapest first.
  Future<List<CurrentPrice>> searchCurrentPrices(String query) async {
    final normalized = normalizeItemName(query);
    if (normalized.isEmpty) return [];

    final snapshot = await _currentPricesRef
        .orderBy('itemNameNormalized')
        .startAt([normalized])
        .endAt(['$normalized'])
        .get();

    final results = snapshot.docs.map(CurrentPrice.fromFirestore).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return results;
  }
}
