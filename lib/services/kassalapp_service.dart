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
/// or the request fails), but it's a third party we don't control: see the
/// "why a fallback exists" note on [ProductSuggestionService].
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

  /// Kassalapp's search appears to token-match rather than decompound —
  /// "ekstra lettmelk" returns nothing at all even though "lettmelk" alone
  /// finds real matches, because the actual product name is "Ekstra Lett
  /// Melk" (three separate words) and "lettmelk" fused into one word never
  /// appears literally in it. If the full query comes back empty and it
  /// has more than one word, retrying with just the last word (Norwegian
  /// qualifiers come before the core noun: "ekstra LETTMELK", "økologisk
  /// MELK") gives the search a real second chance instead of silently
  /// giving up and falling all the way through to Open Food Facts.
  ///
  /// Deliberately does NOT sort by price here — Kassalapp's own relevance
  /// order (however imperfect) is what [ProductSuggestionService] re-ranks
  /// against the query; sorting by price first was actively hiding actual
  /// milk behind a 9,90 kr oat porridge that merely mentions milk in its
  /// name. Price only matters once the *right* product has been found.
  Future<List<ProductSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    var suggestions = await _fetch(trimmed);
    if (suggestions.isEmpty) {
      final words = trimmed.split(RegExp(r'\s+'));
      if (words.length > 1) {
        suggestions = await _fetch(words.last);
      }
    }
    return suggestions.take(8).toList();
  }

  Future<List<ProductSuggestion>> _fetch(String query) async {
    final uri = Uri.https('kassal.app', '/api/v1/products', {
      'search': query,
      // A wider page than we'll actually show, so the non-grocery-vendor
      // filter below has enough left over after excluding wholesale
      // listings.
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

    return products
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
