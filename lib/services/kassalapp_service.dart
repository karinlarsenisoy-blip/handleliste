import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_suggestion.dart';
import '../models/store.dart';

/// API key for Kassalapp (kassal.app) — a Norwegian grocery price/product
/// API. Provided at build/run time via `--dart-define-from-file`, never
/// committed to source control (see config/kassalapp.example.json).
const _envApiKey = String.fromEnvironment('KASSALAPP_API_KEY');

/// Looks up real Norwegian grocery products — name, pack size, image, and
/// current price/store — from Kassalapp. Richer than Open Food Facts (which
/// [ProductSuggestionService] falls back to if this has no key configured
/// or the request fails), but it's a third-party service we don't control:
/// see the "why a fallback exists" note on [ProductSuggestionService].
class KassalappService {
  KassalappService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? _envApiKey;

  final http.Client _client;
  final String _apiKey;

  /// True if a real key is configured (via `--dart-define-from-file`) —
  /// checked against the build-time env value, not the constructor override,
  /// so tests can pass a fake key without affecting this flag.
  static bool get isConfigured => _envApiKey.isNotEmpty;

  Future<List<ProductSuggestion>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https('kassal.app', '/api/v1/products', {
      'search': query,
      // Kassalapp's own result order is relevance, not price — asking for a
      // wider page and sorting client-side avoids missing the genuinely
      // cheapest matches (e.g. a handful of small chains matching first,
      // before the actually-cheapest one further down the unsorted list).
      'size': '30',
    });

    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $_apiKey', 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw KassalappException('Kassalapp returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final products = (data['data'] as List<dynamic>?) ?? [];

    final suggestions = products
        .cast<Map<String, dynamic>>()
        // Kassalapp's product data mixes in listings from non-grocery/
        // wholesale vendors (e.g. "Engrosnett") alongside real store chains
        // — those aren't somewhere an ordinary shopper can actually buy at
        // that price, so they're excluded rather than shown as if they were
        // a legitimate cheap option.
        .where((p) {
          final storeName = (p['store'] as Map<String, dynamic>?)?['name'] as String?;
          return storeName != null && isKnownGroceryStoreName(storeName);
        })
        .map((p) {
          final weight = p['weight'];
          final weightUnit = p['weight_unit'] as String?;
          final store = p['store'] as Map<String, dynamic>?;

          return ProductSuggestion(
            name: p['name'] as String,
            brand: p['brand'] as String?,
            imageUrl: p['image'] as String?,
            quantity: (weight != null && weightUnit != null) ? '$weight $weightUnit' : null,
            price: p['current_price'] as num?,
            storeName: store?['name'] as String?,
            lastObservedAt: _latestPriceDate(p['price_history'] as List<dynamic>?),
          );
        })
        .toList();

    suggestions.sort((a, b) {
      if (a.price == null && b.price == null) return 0;
      if (a.price == null) return 1;
      if (b.price == null) return -1;
      return a.price!.compareTo(b.price!);
    });
    return suggestions.take(8).toList();
  }

  /// Kassalapp's `current_price` is only as fresh as the last entry in its
  /// own price history — we saw listings where that was years old — so this
  /// finds the most recent date in [priceHistory] to know how much to trust
  /// [ProductSuggestion.price].
  static DateTime? _latestPriceDate(List<dynamic>? priceHistory) {
    if (priceHistory == null || priceHistory.isEmpty) return null;

    DateTime? latest;
    for (final entry in priceHistory.cast<Map<String, dynamic>>()) {
      final dateString = entry['date'] as String?;
      if (dateString == null) continue;
      final date = DateTime.tryParse(dateString);
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }
}

class KassalappException implements Exception {
  KassalappException(this.message);
  final String message;

  @override
  String toString() => message;
}
