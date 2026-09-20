/// A typical Norwegian grocery store's walk order, front door to checkout —
/// used to sort a shopping list's items within one store so the user walks
/// the store once instead of backtracking between aisles.
///
/// This is deliberately one generic order shared across all chains, not a
/// per-chain layout: we have no real data on how any specific chain's
/// branches are laid out, and store layout is fairly similar across
/// Norwegian supermarkets anyway (produce near the entrance, frozen and
/// non-food near the end).
///
/// Matching is against the item's own name — there's no user-authored
/// category to read it from (lists have no category/folder level, see
/// ItemService's doc for why), and neither of our product data sources has
/// department info either: Kassalapp's API doesn't return one at all, and
/// Open Food Facts only gets consulted as a fallback for items Kassalapp
/// already failed to find, so it would only ever cover a minority of
/// items. Keyword-matching the name directly works surprisingly well for
/// Norwegian groceries in practice: "Kjøttdeig" already contains "kjøtt",
/// "Poteter" already contains "potet", etc.
const List<({String label, List<String> keywords})> _aisleGroups = [
  (
    label: 'Frukt & grønt',
    keywords: [
      'frukt', 'grønt', 'grønnsak', 'banan', 'eple', 'appelsin', 'potet', 'løk', 'tomat', 'agurk',
      'paprika', 'gulrot', 'gulrøt', 'salat', 'sitron', 'avokado', 'druer', 'pære',
    ],
  ),
  (label: 'Bakervarer', keywords: ['bakst', 'baker', 'brød', 'rundstykke', 'bolle', 'loff']),
  (
    label: 'Meieri',
    keywords: ['meieri', 'melk', 'ost', 'yoghurt', 'yogurt', 'smør', 'egg', 'fløte', 'rømme', 'margarin'],
  ),
  (
    label: 'Kjøtt & fisk',
    keywords: [
      'kjøtt', 'fisk', 'pålegg', 'delikatesse', 'kylling', 'laks', 'bacon', 'pølse', 'skinke',
      'karbonade', 'svin', 'biff', 'torsk',
    ],
  ),
  (
    label: 'Tørrvarer',
    keywords: ['tørrvare', 'kolonial', 'pasta', 'ris', 'krydder', 'mel', 'sukker', 'kaffe', 'te', 'suppe'],
  ),
  (label: 'Drikke', keywords: ['drikke', 'saft', 'brus', 'juice', 'vann', 'øl', 'vin', 'kildevann']),
  (label: 'Frost', keywords: ['frys', 'frost', 'iskrem']),
  (
    label: 'Non-food',
    keywords: [
      'non', 'husholdning', 'hygiene', 'dyrefor', 'vaskemiddel', 'toalettpapir', 'tannkrem',
      'oppvask', 'bleie', 'servietter',
    ],
  ),
];

/// The fixed set of departments offered when mapping a store's layout (see
/// MapStoreLayoutScreen) — a sensible, consistent list to tap through in
/// walking order, rather than whatever ad-hoc category names a user might
/// otherwise have typed.
List<String> get aisleGroupLabels => _aisleGroups.map((g) => g.label).toList();

final RegExp _wordSplitter = RegExp(r'[^a-zæøå]+');

/// The department [itemName] most likely belongs to (one of
/// [aisleGroupLabels]), or null if nothing matched. Exposed separately from
/// [aisleRank] so a specific branch's crowdsourced layout (see
/// MapStoreLayoutScreen/StoreLayout.rankOf, which stores an ordering of
/// these same labels) can be consulted for this exact item instead of the
/// generic fallback order.
///
/// Matches whole words against a keyword *stem* (`word.startsWith(keyword)`,
/// to still catch Norwegian plurals like "gulrøtter" from the stem
/// "gulrøt") rather than checking the keyword as a substring of the whole
/// name — plain substring matching once matched "Frost" against the "ost"
/// (cheese) keyword, since "frost" contains "ost" as letters.
String? aisleLabelFor(String? itemName) {
  if (itemName == null) return null;
  final words = itemName.toLowerCase().split(_wordSplitter).where((w) => w.isNotEmpty);
  for (final group in _aisleGroups) {
    if (words.any((word) => group.keywords.any(word.startsWith))) return group.label;
  }
  return null;
}

/// Sort key for an item by [itemName] — an item whose name doesn't match
/// any known aisle sorts after every one that does, but still keeps its
/// relative order rather than jumping to the front.
int aisleRank(String? itemName) {
  final label = aisleLabelFor(itemName);
  if (label == null) return _aisleGroups.length;
  return aisleGroupLabels.indexOf(label);
}
