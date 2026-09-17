import 'package:cloud_firestore/cloud_firestore.dart';

/// The latest known price for one item at one chain — a denormalized
/// "current state" row kept alongside the full [PriceObservation] history,
/// so a price lookup doesn't need to scan every observation ever made.
class CurrentPrice {
  CurrentPrice({
    required this.storeChainId,
    required this.itemName,
    required this.itemNameNormalized,
    required this.price,
    required this.lastObservedAt,
    required this.sampleCount,
  });

  final String storeChainId;
  final String itemName;
  final String itemNameNormalized;
  final num price;
  final DateTime lastObservedAt;

  /// How many observations have rolled into this row — a rough confidence
  /// signal (one lone receipt vs. dozens agreeing on the same price).
  final int sampleCount;

  factory CurrentPrice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CurrentPrice(
      storeChainId: data['storeChainId'] as String,
      itemName: data['itemName'] as String,
      itemNameNormalized: data['itemNameNormalized'] as String,
      price: data['price'] as num,
      lastObservedAt: (data['lastObservedAt'] as Timestamp).toDate(),
      sampleCount: data['sampleCount'] as int? ?? 1,
    );
  }
}
