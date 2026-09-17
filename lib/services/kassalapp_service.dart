import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_suggestion.dart';

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
      'size': '8',
    });

    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $_apiKey', 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw KassalappException('Kassalapp returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final products = (data['data'] as List<dynamic>?) ?? [];

    return products.cast<Map<String, dynamic>>().map((p) {
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
      );
    }).toList();
  }
}

class KassalappException implements Exception {
  KassalappException(this.message);
  final String message;

  @override
  String toString() => message;
}
