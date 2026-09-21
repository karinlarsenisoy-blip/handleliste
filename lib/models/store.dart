import '../config/market.dart';

/// A known grocery chain the user can pick a receipt's store from.
class Store {
  const Store(this.id, this.name);

  final String id;
  final String name;
}

/// The most common grocery chains per market, plus a catch-all for the
/// rest. Keyed by [currentMarket] so a future second market (e.g. Sweden's
/// ICA/Willys/Hemköp/City Gross) is a new map entry, not a rewrite of every
/// call site that already reads [knownStores] — only `'no'` is populated
/// today.
const Map<String, List<Store>> _storesByMarket = {
  'no': [
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
  ],
};

List<Store> get knownStores => _storesByMarket[currentMarket]!;

/// Substrings (lowercase) of real, consumer-facing grocery retailer names
/// per market — used to filter out non-store listings (e.g. wholesale/B2B
/// vendors like "Engrosnett") that show up mixed into third-party product
/// data alongside actual grocery chains.
const Map<String, List<String>> _groceryStoreNameFragmentsByMarket = {
  'no': [
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
  ],
};

/// Whether [storeName] looks like a real, consumer-facing grocery store in
/// [currentMarket] rather than a wholesaler or other non-grocery vendor.
bool isKnownGroceryStoreName(String storeName) {
  final lower = storeName.toLowerCase();
  final fragments = _groceryStoreNameFragmentsByMarket[currentMarket] ?? const [];
  return fragments.any(lower.contains);
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
