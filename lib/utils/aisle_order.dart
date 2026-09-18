/// A typical Norwegian grocery store's walk order, front door to checkout —
/// used to sort a shopping list's items within one store so the user walks
/// the store once instead of backtracking between aisles.
///
/// This is deliberately one generic order shared across all chains, not a
/// per-chain layout: we have no real data on how any specific chain's
/// branches are laid out, and store layout is fairly similar across
/// Norwegian supermarkets anyway (produce near the entrance, frozen and
/// non-food near the end). Matching is by keyword against the user's own
/// list category name (e.g. "Meieri", "Frukt & grønt") — the same
/// free-text categories already used to organize the list — so this needs
/// no new data source.
const List<({String label, List<String> keywords})> _aisleGroups = [
  (label: 'Frukt & grønt', keywords: ['frukt', 'grønt', 'grønnsak']),
  (label: 'Bakervarer', keywords: ['bakst', 'baker', 'brød']),
  (label: 'Meieri', keywords: ['meieri', 'melk', 'ost', 'yoghurt', 'smør', 'egg']),
  (label: 'Kjøtt & fisk', keywords: ['kjøtt', 'fisk', 'pålegg', 'delikatesse']),
  (label: 'Tørrvarer', keywords: ['tørrvare', 'kolonial', 'pasta', 'ris', 'krydder']),
  (label: 'Drikke', keywords: ['drikke', 'saft', 'brus']),
  (label: 'Frost', keywords: ['frys', 'frost']),
  (label: 'Non-food', keywords: ['non', 'husholdning', 'hygiene', 'dyrefor', 'vaskemiddel']),
];

final RegExp _wordSplitter = RegExp(r'[^a-zæøå]+');

/// Sort key for [categoryName] — unrecognized or missing category names
/// (e.g. a catch-all "Diverse") sort after every known aisle, but still
/// before nothing: they keep whatever relative order they already had.
///
/// Matches whole words against a keyword *stem* (`word.startsWith(keyword)`,
/// to still catch Norwegian plurals like "grønnsaker" from the stem
/// "grønnsak") rather than checking the keyword as a substring of the whole
/// category name — plain substring matching once matched "Frost" against
/// the "ost" (cheese) keyword, since "frost" contains "ost" as letters.
int aisleRank(String? categoryName) {
  if (categoryName == null) return _aisleGroups.length;
  final words = categoryName.toLowerCase().split(_wordSplitter).where((w) => w.isNotEmpty);
  for (var i = 0; i < _aisleGroups.length; i++) {
    final keywords = _aisleGroups[i].keywords;
    if (words.any((word) => keywords.any(word.startsWith))) return i;
  }
  return _aisleGroups.length;
}
