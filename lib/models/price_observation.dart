import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/market.dart';

/// Lowercases, trims and collapses whitespace so the same product typed
/// slightly differently on two receipts still groups together. Deliberately
/// simple for now — matching "Tine Lettmelk 1l" with "TINE LETTMELK 1,0% 1L"
/// as the same product is a harder problem for a later round.
String normalizeItemName(String raw) => raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// One anonymous data point: "this item cost this much at this chain on
/// this date". Never carries a user id — only ever store+item+price+date,
/// never who bought it. This is the append-only, never-edited raw feed
/// behind the [CurrentPrice] lookup table.
class PriceObservation {
  PriceObservation({
    required this.storeChainId,
    required this.itemName,
    required this.price,
    required this.observedAt,
    this.market = currentMarket,
  });

  final String storeChainId;
  final String itemName;
  final num price;
  final DateTime observedAt;

  /// Which country/market this price is from (see lib/config/market.dart).
  /// Defaults to the app's current single market so existing call sites
  /// don't need to pass it — only matters once a second market exists.
  final String market;

  String get itemNameNormalized => normalizeItemName(itemName);

  Map<String, dynamic> toMap() => {
        'storeChainId': storeChainId,
        'itemName': itemName,
        'itemNameNormalized': itemNameNormalized,
        'price': price,
        'observedAt': Timestamp.fromDate(observedAt),
        'contributedAt': FieldValue.serverTimestamp(),
        'market': market,
      };
}
