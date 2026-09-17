/// A known grocery chain the user can pick a receipt's store from.
class Store {
  const Store(this.id, this.name);

  final String id;
  final String name;
}

/// The most common Norwegian grocery chains, plus a catch-all for the rest.
const List<Store> knownStores = [
  Store('kiwi', 'Kiwi'),
  Store('rema1000', 'Rema 1000'),
  Store('coop_extra', 'Coop Extra'),
  Store('coop_mega', 'Coop Mega'),
  Store('coop_prix', 'Coop Prix'),
  Store('coop_obs', 'Coop Obs'),
  Store('meny', 'Meny'),
  Store('spar', 'Spar'),
  Store('bunnpris', 'Bunnpris'),
  Store('joker', 'Joker'),
  Store('annet', 'Annet'),
];

/// Substrings (lowercase) of real, consumer-facing Norwegian grocery
/// retailers — used to filter out non-store listings (e.g. wholesale/B2B
/// vendors like "Engrosnett") that show up mixed into third-party product
/// data alongside actual grocery chains.
const List<String> _knownGroceryStoreNameFragments = [
  'kiwi',
  'rema',
  'coop',
  'extra',
  'prix',
  'mega',
  'obs',
  'spar',
  'meny',
  'joker',
  'bunnpris',
  'oda', // Oda (oda.com) is a real online grocery retailer, not a wholesaler.
];

/// Whether [storeName] looks like a real, consumer-facing Norwegian grocery
/// store rather than a wholesaler or other non-grocery vendor.
bool isKnownGroceryStoreName(String storeName) {
  final lower = storeName.toLowerCase();
  return _knownGroceryStoreNameFragments.any(lower.contains);
}

/// The display name for a chain id (e.g. `'coop_extra'` -> `'Coop Extra'`),
/// used when combining our own crowdsourced prices (keyed by chain id) with
/// a display-name-keyed source like Kassalapp.
String displayNameForChainId(String chainId) {
  for (final store in knownStores) {
    if (store.id == chainId) return store.name;
  }
  return chainId;
}

/// Normalizes a store name from a third-party source (which may use
/// inconsistent casing, e.g. "KIWI" vs "Kiwi" across different product
/// listings) to one consistent display form, so the same real store never
/// gets split into separate entries just because of how it was capitalized.
String canonicalStoreName(String rawName) {
  final lower = rawName.trim().toLowerCase();
  for (final store in knownStores) {
    if (store.id == lower || store.name.toLowerCase() == lower) return store.name;
  }
  return rawName
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}
