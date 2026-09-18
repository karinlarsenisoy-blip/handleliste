import 'package:flutter/material.dart';

import '../models/cheapest_store_analysis.dart';
import '../models/item.dart';
import '../models/shopping_split.dart';
import '../models/store_location.dart';
import '../models/store_total.dart';
import '../services/category_service.dart';
import '../services/cheapest_store_service.dart';
import '../services/item_service.dart';
import '../services/location_service.dart';
import '../services/store_locator_service.dart';
import '../utils/aisle_order.dart';
import '../utils/distance.dart';
import 'active_trip_screen.dart';

/// Shows two ways to buy everything on one shopping list as cheaply as
/// possible: pick a single store to visit, or split the list across
/// whichever stores are individually cheapest per item. Both come from one
/// [CheapestStoreService.analyze] call so they're always consistent with
/// each other — see that method's doc for why that matters.
///
/// Optionally, tapping "Bruk min posisjon" adds real distance to the
/// nearest branch of each chain (via [StoreLocatorService]/OpenStreetMap) —
/// opt-in, since it needs a location permission and isn't required for the
/// core price comparison to work.
class CheapestStoreScreen extends StatefulWidget {
  CheapestStoreScreen({
    super.key,
    required this.uid,
    required this.listId,
    required this.listName,
    CategoryService? categoryService,
    ItemService? itemService,
    CheapestStoreService? cheapestStoreService,
    LocationService? locationService,
    StoreLocatorService? storeLocatorService,
  })  : categoryService = categoryService ?? CategoryService(),
        itemService = itemService ?? ItemService(),
        cheapestStoreService = cheapestStoreService ?? CheapestStoreService(),
        locationService = locationService ?? LocationService(),
        storeLocatorService = storeLocatorService ?? StoreLocatorService();

  final String uid;
  final String listId;
  final String listName;
  final CategoryService categoryService;
  final ItemService itemService;
  final CheapestStoreService cheapestStoreService;
  final LocationService locationService;
  final StoreLocatorService storeLocatorService;

  @override
  State<CheapestStoreScreen> createState() => _CheapestStoreScreenState();
}

/// A short, human "how fresh is this price" label — the whole point of
/// showing it is to build trust in an "as of right now" feature, so it
/// needs to be honest when a price is a few weeks old, not just always say
/// something reassuring-sounding.
String _freshnessLabel(DateTime lastObservedAt) {
  final age = DateTime.now().difference(lastObservedAt);
  if (age.inHours < 24) return 'Sett i dag';
  if (age.inDays == 1) return 'Sett i går';
  return 'Sett for ${age.inDays} dager siden';
}

class _Loaded {
  _Loaded(this.itemNames, this.analysis, this.itemLookup);
  final List<String> itemNames;
  final CheapestStoreAnalysis analysis;

  /// Where each item name actually lives (which category, and that
  /// category's name), so a confirmed trip can check items off for real via
  /// [ItemService.toggleItem] instead of just toggling something on screen
  /// that forgets itself when you leave the page — and so items can be
  /// sorted by store-aisle order using the category name (see
  /// [aisleRank]).
  final Map<String, ({Item item, String categoryId, String categoryName})> itemLookup;
}

class _CheapestStoreScreenState extends State<CheapestStoreScreen> {
  late final Future<_Loaded> _future = _load();

  static const _radiusOptions = [1000, 3000, 5000, 10000, 20000];

  ({double latitude, double longitude})? _position;
  List<StoreLocation> _nearbyStores = [];
  bool _isLoadingLocation = false;
  String? _locationMessage;
  int _radiusMeters = 3000;

  Future<void> _useMyLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    final result = await widget.locationService.getCurrentPosition();
    if (!result.isSuccess) {
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = switch (result.failureReason!) {
          LocationFailureReason.permissionDenied =>
            'Fikk ikke tilgang til posisjonen din — sjekk posisjonstillatelsen for denne siden i nettleseren.',
          LocationFailureReason.timeout => 'Brukte for lang tid på å finne posisjonen din — prøv igjen.',
          LocationFailureReason.unknown =>
            'Klarte ikke å hente posisjonen din${result.debugMessage != null ? ' (${result.debugMessage})' : ''}.',
        };
      });
      return;
    }

    final position = (latitude: result.latitude!, longitude: result.longitude!);
    setState(() => _position = position);
    await _refreshNearbyStores();
  }

  /// Re-queries nearby stores for the current [_position] — used both right
  /// after first getting a position, and whenever the user changes the
  /// search radius (no need to ask the browser for location again for that,
  /// we already have it).
  Future<void> _refreshNearbyStores() async {
    final position = _position;
    if (position == null) return;

    setState(() => _isLoadingLocation = true);
    final nearby = await widget.storeLocatorService.findNearby(
      position.latitude,
      position.longitude,
      radiusMeters: _radiusMeters.toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _nearbyStores = nearby;
      _isLoadingLocation = false;
      _locationMessage = nearby.isEmpty
          ? 'Fant ingen butikker i nærheten akkurat nå (eller kunne ikke hente butikkposisjoner).'
          : null;
    });
  }

  void _onRadiusChanged(int? meters) {
    if (meters == null || meters == _radiusMeters) return;
    setState(() => _radiusMeters = meters);
    _refreshNearbyStores();
  }

  /// The nearest known branch of [chainName] to [_position], if any.
  ({StoreLocation location, double distanceMeters})? _nearestBranch(String chainName) {
    final position = _position;
    if (position == null) return null;

    StoreLocation? nearest;
    double? nearestDistance;
    for (final location in _nearbyStores) {
      if (location.chainName != chainName) continue;
      final distance = haversineMeters(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearest = location;
      }
    }
    if (nearest == null || nearestDistance == null) return null;
    return (location: nearest, distanceMeters: nearestDistance);
  }

  Future<_Loaded> _load() async {
    final categories = await widget.categoryService.watchCategories(widget.uid, widget.listId).first;
    final itemNames = <String>[];
    final itemLookup = <String, ({Item item, String categoryId, String categoryName})>{};
    for (final category in categories) {
      final items = await widget.itemService.watchItems(widget.uid, widget.listId, category.id).first;
      // Deliberately NOT filtering by isChecked: that only means "in the
      // physical cart right now" (see ActiveTripScreen) — it's not a
      // confirmation that the item was actually bought, let alone bought at
      // the store/price this analysis would assign it to. Mixing that
      // uncertain signal into price planning would be misleading.
      for (final item in items) {
        itemNames.add(item.name);
        itemLookup[item.name] = (item: item, categoryId: category.id, categoryName: category.name);
      }
    }
    final analysis = await widget.cheapestStoreService.analyze(itemNames);
    return _Loaded(itemNames, analysis, itemLookup);
  }

  /// The split, but only ever assigning an item to a store we actually know
  /// a nearby branch of — an item whose cheapest store has no known branch
  /// within the search radius falls through to the next-cheapest store that
  /// does, rather than sending the user somewhere they have no real branch
  /// to go to. Rebuilt from [storeTotals] (already-fetched prices) rather
  /// than re-querying anything, so changing the radius or getting a
  /// position is instant.
  ShoppingSplit _reachableSplit(List<String> itemNames, List<StoreTotal> storeTotals, Set<String> reachableStoreNames) {
    final candidatesByItem = <String, List<({String storeName, num price, DateTime lastObservedAt})>>{};
    for (final storeTotal in storeTotals) {
      if (!reachableStoreNames.contains(storeTotal.storeName)) continue;
      for (final item in storeTotal.matchedItems) {
        (candidatesByItem[item.name] ??= []).add(
          (storeName: storeTotal.storeName, price: item.price, lastObservedAt: item.lastObservedAt),
        );
      }
    }

    final assignments = <ItemAssignment>[];
    final unmatched = <String>[];
    for (final itemName in itemNames) {
      final candidates = candidatesByItem[itemName] ?? const [];
      if (candidates.isEmpty) {
        unmatched.add(itemName);
        continue;
      }
      var cheapest = candidates.first;
      for (final candidate in candidates.skip(1)) {
        if (candidate.price < cheapest.price) cheapest = candidate;
      }
      assignments.add(ItemAssignment(
        itemName: itemName,
        storeName: cheapest.storeName,
        price: cheapest.price,
        lastObservedAt: cheapest.lastObservedAt,
      ));
    }
    return ShoppingSplit(assignments: assignments, unmatchedItems: unmatched);
  }

  void _showDetails(StoreTotal storeTotal, List<String> allItemNames) {
    final matchedNames = storeTotal.matchedItems.map((i) => i.name).toSet();
    final missingNames = allItemNames.where((name) => !matchedNames.contains(name)).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(storeTotal.storeName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${storeTotal.matchedItemCount} av ${storeTotal.totalItemCount} varer · '
              '${storeTotal.total.toStringAsFixed(2)} kr totalt',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 32),
            if (storeTotal.matchedItems.isNotEmpty) ...[
              Text('Funnet', style: Theme.of(context).textTheme.titleMedium),
              for (final item in storeTotal.matchedItems)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text(item.name),
                  subtitle: Text(_freshnessLabel(item.lastObservedAt)),
                  trailing: Text('${item.price.toStringAsFixed(2)} kr'),
                ),
            ],
            if (missingNames.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Mangler her', style: Theme.of(context).textTheme.titleMedium),
              for (final name in missingNames)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cancel_outlined, color: Colors.grey),
                  title: Text(name),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStoreTab(List<String> itemNames, List<StoreTotal> totals) {
    if (itemNames.isEmpty) {
      return const Center(child: Text('Listen er tom — legg til varer først.'));
    }
    if (totals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Fant ingen kjente priser for varene på denne listen ennå. '
            'Legg inn flere kvitteringer, eller prøv varenavn som matcher kjente produkter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: totals.length,
      itemBuilder: (context, index) {
        final storeTotal = totals[index];
        final isCheapest = index == 0;
        final nearest = _nearestBranch(storeTotal.storeName);

        return Card(
          color: isCheapest ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            onTap: () => _showDetails(storeTotal, itemNames),
            leading: isCheapest ? const Icon(Icons.emoji_events_outlined) : null,
            title: Text(storeTotal.storeName, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${storeTotal.matchedItemCount} av ${storeTotal.totalItemCount} varer funnet'),
                if (_position != null)
                  Text(
                    nearest == null
                        ? 'Ingen kjent butikk i nærheten'
                        : '${(nearest.distanceMeters / 1000).toStringAsFixed(1)} km · ${nearest.location.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            isThreeLine: _position != null,
            trailing: Text(
              '${storeTotal.total.toStringAsFixed(2)} kr',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      },
    );
  }

  /// How much cheaper the split is than buying the same (overlapping) items
  /// at the single best store — only counting items that exist at both, so
  /// this never overstates the saving by crediting items that store doesn't
  /// even carry. That best store's own total may well be higher than what
  /// its card shows in the split tab below: some of "its" items turn out
  /// cheaper elsewhere, so the split hands those to other stores instead.
  ({num amount, num singleStoreTotal, String singleStoreName, int overlapCount, int listItemCount})?
      _computeSavings(
    ShoppingSplit split,
    List<StoreTotal> singleStoreTotals,
  ) {
    if (singleStoreTotals.isEmpty) return null;
    final bestSingleStore = singleStoreTotals.first;
    final priceAtBestStore = {for (final item in bestSingleStore.matchedItems) item.name: item.price};

    num singleStoreCost = 0;
    num splitCostForSameItems = 0;
    var overlapCount = 0;
    for (final assignment in split.assignments) {
      final priceThere = priceAtBestStore[assignment.itemName];
      if (priceThere == null) continue;
      singleStoreCost += priceThere;
      splitCostForSameItems += assignment.price;
      overlapCount++;
    }
    if (overlapCount == 0) return null;

    return (
      amount: singleStoreCost - splitCostForSameItems,
      singleStoreTotal: singleStoreCost,
      singleStoreName: bestSingleStore.storeName,
      overlapCount: overlapCount,
      listItemCount: bestSingleStore.totalItemCount,
    );
  }

  /// Stores to visit, in the order to actually drive/walk them: nearest
  /// known branch first. Stores whose branch distance we don't know (no
  /// location permission yet, or no matching branch nearby) sort last,
  /// keeping their relative order — better than guessing where they'd fit.
  List<MapEntry<String, List<ItemAssignment>>> _stopsInVisitOrder(
    Map<String, List<ItemAssignment>> byStore,
  ) {
    final entries = byStore.entries.toList();
    if (_position == null) return entries;

    final distances = {for (final key in byStore.keys) key: _nearestBranch(key)?.distanceMeters};
    entries.sort((a, b) {
      final distanceA = distances[a.key];
      final distanceB = distances[b.key];
      if (distanceA == null && distanceB == null) return 0;
      if (distanceA == null) return 1;
      if (distanceB == null) return -1;
      return distanceA.compareTo(distanceB);
    });
    return entries;
  }

  Widget _buildSplitTab(
    List<String> itemNames,
    ShoppingSplit fullSplit,
    List<StoreTotal> singleStoreTotals,
    Map<String, ({Item item, String categoryId, String categoryName})> itemLookup,
  ) {
    if (fullSplit.assignments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Fant ingen kjente priser for varene på denne listen ennå.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Once we know which chains actually have a branch nearby, keep the
    // split from ever suggesting one that doesn't — reassign those items to
    // the cheapest store we can actually reach instead.
    final reachableStoreNames = _nearbyStores.map((s) => s.chainName).toSet();
    final isReachabilityAware = _position != null && reachableStoreNames.isNotEmpty;
    final split = isReachabilityAware
        ? _reachableSplit(itemNames, singleStoreTotals, reachableStoreNames)
        : fullSplit;
    final excludedStores = isReachabilityAware
        ? fullSplit.assignmentsByStore.keys.where((name) => !reachableStoreNames.contains(name)).toList()
        : const <String>[];

    // Sorted by store-visit order first, then each stop's own items sorted
    // by where they'd typically be in the store — walk it once instead of
    // criss-crossing between aisles.
    final stops = _stopsInVisitOrder(split.assignmentsByStore);
    for (final stop in stops) {
      stop.value.sort((a, b) {
        final rankA = aisleRank(itemLookup[a.itemName]?.categoryName);
        final rankB = aisleRank(itemLookup[b.itemName]?.categoryName);
        return rankA.compareTo(rankB);
      });
    }
    final savings = _computeSavings(split, singleStoreTotals);
    final savingsItemsLabel = savings == null
        ? ''
        : savings.overlapCount == savings.listItemCount
            ? 'alle dine ${savings.listItemCount} varer'
            : 'de ${savings.overlapCount} av dine ${savings.listItemCount} varer som også finnes';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (excludedStores.isNotEmpty) ...[
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Fant ingen kjent ${excludedStores.join(', ')}-butikk innenfor '
                '${(_radiusMeters / 1000).toStringAsFixed(_radiusMeters % 1000 == 0 ? 0 : 1)} km — '
                'varene som var billigst der er lagt til den billigste butikken du faktisk kan nå i stedet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (savings != null) ...[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savings.amount > 0
                        ? 'Du sparer ${savings.amount.toStringAsFixed(2)} kr'
                        : 'Ingen besparelse ved å splitte akkurat nå',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hvis du i stedet kjøpte $savingsItemsLabel kun hos ${savings.singleStoreName}, ville det '
                    'kostet ${savings.singleStoreTotal.toStringAsFixed(2)} kr der. Noen av dem er billigere '
                    'andre steder — derfor er de satt til en annen butikk under.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_position != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Rekkefølgen under er sortert etter avstand fra deg — nærmeste stopp først.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (var stopIndex = 0; stopIndex < stops.length; stopIndex++) ...[
          () {
            final entry = stops[stopIndex];
            final nearest = _nearestBranch(entry.key);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_position != null) ...[
                          CircleAvatar(radius: 12, child: Text('${stopIndex + 1}')),
                          const SizedBox(width: 8),
                        ],
                        Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    if (_position != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          nearest == null
                              ? 'Ingen kjent butikk i nærheten'
                              : '${(nearest.distanceMeters / 1000).toStringAsFixed(1)} km · ${nearest.location.name}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 4),
                    for (final assignment in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(assignment.itemName)),
                            Text(
                              _freshnessLabel(assignment.lastObservedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text('${assignment.price.toStringAsFixed(2)} kr'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }(),
          const SizedBox(height: 8),
        ],
        if (split.unmatchedItems.isNotEmpty) ...[
          const Divider(),
          Text('Ingen kjent pris', style: Theme.of(context).textTheme.titleMedium),
          for (final name in split.unmatchedItems)
            ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(name)),
        ],
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Totalt · ${stops.length} butikker', style: Theme.of(context).textTheme.titleMedium),
            Text('${split.total.toStringAsFixed(2)} kr', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Bekreft rute og start handletur'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveTripScreen(
                uid: widget.uid,
                listId: widget.listId,
                listName: widget.listName,
                stops: stops,
                itemLookup: itemLookup,
                itemService: widget.itemService,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Billigst for «${widget.listName}»'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Én butikk'),
              Tab(text: 'Handletur'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingLocation ? null : _useMyLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        _position == null ? 'Bruk min posisjon' : 'Oppdater posisjon',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _radiusMeters,
                    onChanged: _isLoadingLocation ? null : _onRadiusChanged,
                    items: [
                      for (final meters in _radiusOptions)
                        DropdownMenuItem(
                          value: meters,
                          child: Text('${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1)} km'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isLoadingLocation
                      ? 'Søker etter butikker i nærheten...'
                      : 'Viser avstand fra deg til nærmeste butikk av hvert slag innenfor valgt søkeradius',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_locationMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _locationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: FutureBuilder<_Loaded>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
                  }

                  final loaded = snapshot.data!;
                  return TabBarView(
                    children: [
                      _buildSingleStoreTab(loaded.itemNames, loaded.analysis.storeTotals),
                      _buildSplitTab(
                        loaded.itemNames,
                        loaded.analysis.split,
                        loaded.analysis.storeTotals,
                        loaded.itemLookup,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
