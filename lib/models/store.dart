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
