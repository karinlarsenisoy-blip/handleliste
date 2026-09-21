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

  /// Market-prefixed so a future second market can never collide with (or
  /// need to migrate) Norway's existing rows, even if a chain id happens to
  /// be spelled the same way in both — see lib/config/market.dart.
  String _currentPriceDocId(String market, String storeChainId, String itemNameNormalized) {
    final safeName = itemNameNormalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '$market-$storeChainId-$safeName';
  }

  /// Contributes one anonymous price observation and refreshes the
  /// corresponding "current price" row. Safe to call once per receipt line
  /// the user opts to share.
  Future<void> contributeObservation(PriceObservation observation) async {
    await _observationsRef.add(observation.toMap());

    final docRef = _currentPricesRef.doc(
      _currentPriceDocId(observation.market, observation.storeChainId, observation.itemNameNormalized),
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
        'market': observation.market,
      });
    });
  }

  /// Every chain's current price for items whose normalized name starts
  /// with [query] (e.g. "bana" matches "bananer"), cheapest first.
  ///
  /// Not yet filtered by market — harmless while `currentMarket` is the
  /// only market any row is ever written with, but once a second market
  /// exists this needs a `.where('market', isEqualTo: currentMarket)`
  /// clause here (and a matching composite index alongside the
  /// `itemNameNormalized` orderBy/startAt/endAt, since Firestore requires
  /// one for an equality filter combined with a range on a different
  /// field) — otherwise a Norwegian and Swedish price for the same item
  /// name would be compared as if they were the same currency.
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
