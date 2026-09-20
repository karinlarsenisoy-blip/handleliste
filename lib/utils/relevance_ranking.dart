import '../models/product_suggestion.dart';

/// Both Kassalapp and Open Food Facts return anything containing [query]
/// as a substring anywhere in the name, so searching "melk" surfaces
/// "Melkesjokolade" (milk chocolate) and "Havregrøt m/Melk" (oat
/// porridge made with milk) ahead of actual milk — confirmed directly
/// against Kassalapp's API: its own relevance order for "melk" has no
/// plain milk at all in the first 15 results. This re-ranks by where and
/// how [query] appears as a real word in the name, cheapest-first only
/// as a tiebreak within the same relevance tier.
///
/// Shared by [ProductSuggestionService] (the search-suggestion dropdown)
/// and [CheapestStoreService] (picking which Kassalapp listing represents
/// a store for a given item name) — both consume the same raw, unranked
/// suggestion lists and need the same fix for the same reason.
List<ProductSuggestion> sortSuggestionsByRelevance(List<ProductSuggestion> suggestions, String query) {
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

final RegExp _wordSplitter = RegExp(r'[^a-zæøå]+');

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
