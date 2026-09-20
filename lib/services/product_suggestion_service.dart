import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product_suggestion.dart';
import 'kassalapp_service.dart';

/// Looks up product suggestions (name, pack size, photo — and, when
/// available, price/store) so the user can pick a specific known product
/// instead of typing free text.
///
/// Tries [KassalappService] first (a Norwegian grocery product/price API —
/// far more complete for Norwegian pack sizes and prices), and falls back to
/// Open Food Facts if Kassalapp has no key configured or the request fails.
/// This fallback exists deliberately: Kassalapp is a third party we don't
/// control and (per a deliberate decision, see project notes) could in
/// principle restrict our access later, so the feature is built to degrade
/// gracefully rather than depend on a single provider.
///
/// The Open Food Facts path uses the classic `cgi/search.pl` endpoint rather
/// than Open Food Facts' newer search-a-licious API: the newer one ranks
/// results much better, but its response has no CORS header, so a browser
/// blocks it outright — the classic endpoint sends
/// `Access-Control-Allow-Origin: *` and works from Flutter web too. A
/// `countries` facet filter for Norway keeps results relevant (the
/// unfiltered endpoint matches "melk"/"cola" against products from anywhere
/// in the world, since Open Food Facts is multilingual).
class ProductSuggestionService {
  ProductSuggestionService({http.Client? client, KassalappService? kassalappService})
      : _client = client ?? http.Client(),
        _kassalappService = kassalappService ?? KassalappService();

  final http.Client _client;
  final KassalappService _kassalappService;

  Future<List<ProductSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (KassalappService.isConfigured) {
      try {
        final results = await _kassalappService.search(trimmed);
        if (results.isNotEmpty) return _sortByRelevance(results, trimmed);
      } catch (_) {
        // Fall through to Open Food Facts below.
      }
    }

    return _sortByRelevance(await _searchOpenFoodFacts(trimmed), trimmed);
  }

  /// Both Kassalapp and Open Food Facts return anything containing [query]
  /// as a substring anywhere in the name, so searching "melk" surfaces
  /// "Melkesjokolade" (milk chocolate) and "Havregrøt m/Melk" (oat
  /// porridge made with milk) ahead of actual milk — confirmed directly
  /// against Kassalapp's API: its own relevance order for "melk" has no
  /// plain milk at all in the first 15 results. This re-ranks by where and
  /// how [query] appears as a real word in the name, cheapest-first only
  /// as a tiebreak within the same relevance tier (price was previously
  /// the *primary* sort here, which is what let a 9,90 kr porridge outrank
  /// actually-relevant, pricier milk).
  List<ProductSuggestion> _sortByRelevance(List<ProductSuggestion> suggestions, String query) {
    final scored = suggestions.map((s) => (suggestion: s, score: _relevanceScore(s.name, query))).toList()
      ..sort((a, b) {
        final byRelevance = a.score.compareTo(b.score);
        if (byRelevance != 0) return byRelevance;
        final priceA = a.suggestion.price;
        final priceB = b.suggestion.price;
        if (priceA == null && priceB == null) return 0;
        if (priceA == null) return 1;
        if (priceB == null) return -1;
        return priceA.compareTo(priceB);
      });
    return scored.map((s) => s.suggestion).toList();
  }

  static final RegExp _wordSplitter = RegExp(r'[^a-zæøå]+');

  /// Lower is more relevant. A word in [name] that equals, ends with, or is
  /// a short variant (catching plurals like "epler" from "eple") of
  /// [query] scores by its word position (earlier = better) — this also
  /// naturally matches Norwegian compounds where the core noun is the
  /// suffix, like "lettmelk" or "kokosmelk". A word that merely *starts*
  /// with [query] but keeps going into unrelated territory ("melkesjoko
  /// lade", "melkefri") scores much lower instead of counting as a real
  /// match. A name where the query only appears right after "m/" or "med"
  /// ("Havregrøt m/Melk" — milk as an ingredient of a *different*
  /// product) is pushed down near the bottom on purpose.
  int _relevanceScore(String name, String query) {
    final normalizedQuery = query.toLowerCase();
    if (normalizedQuery.isEmpty) return 0;
    final lowerName = name.toLowerCase();

    if (lowerName.contains('m/$normalizedQuery') || lowerName.contains('med $normalizedQuery')) {
      return 1500;
    }

    final words = lowerName.split(_wordSplitter).where((w) => w.isNotEmpty).toList();
    var weakScore = 2000;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final isShortVariant = word.length <= normalizedQuery.length + 3;
      final isStrongMatch = word == normalizedQuery ||
          word.endsWith(normalizedQuery) ||
          (word.startsWith(normalizedQuery) && isShortVariant);
      if (isStrongMatch) return i;

      if (word.startsWith(normalizedQuery) && weakScore == 2000) {
        weakScore = 1000 + i;
      }
    }
    return weakScore;
  }

  Future<List<ProductSuggestion>> _searchOpenFoodFacts(String query) async {
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '8',
      'tagtype_0': 'countries',
      'tag_contains_0': 'contains',
      'tag_0': 'norway',
      'fields': 'product_name,brands,image_small_url,quantity',
    });

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = (data['products'] as List<dynamic>?) ?? [];

      final suggestions = products
          .cast<Map<String, dynamic>>()
          .where((p) => (p['product_name'] as String?)?.trim().isNotEmpty == true)
          .map((p) => ProductSuggestion(
                name: (p['product_name'] as String).trim(),
                brand: (p['brands'] as String?)?.split(',').first.trim(),
                imageUrl: p['image_small_url'] as String?,
                quantity: (p['quantity'] as String?)?.trim().isEmpty == true
                    ? null
                    : p['quantity'] as String?,
              ))
          .toList();

      // Open Food Facts is community-contributed, so pack size is often left
      // blank on some entries — put the ones that do have it first rather
      // than leaving that mixed in at random positions.
      suggestions.sort((a, b) {
        if ((a.quantity == null) == (b.quantity == null)) return 0;
        return a.quantity == null ? 1 : -1;
      });
      return suggestions;
    } catch (_) {
      // Network hiccup or unexpected response shape — suggestions are a
      // nice-to-have, so fail quietly and let the user keep typing free text.
      return [];
    }
  }
}
