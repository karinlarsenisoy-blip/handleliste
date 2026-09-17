import 'package:flutter/material.dart';

import '../models/cheapest_store_analysis.dart';
import '../models/shopping_split.dart';
import '../models/store_location.dart';
import '../models/store_total.dart';
import '../services/category_service.dart';
import '../services/cheapest_store_service.dart';
import '../services/item_service.dart';
import '../services/location_service.dart';
import '../services/store_locator_service.dart';
import '../utils/distance.dart';

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
  _Loaded(this.itemNames, this.analysis);
  final List<String> itemNames;
  final CheapestStoreAnalysis analysis;
}

class _CheapestStoreScreenState extends State<CheapestStoreScreen> {
  late final Future<_Loaded> _future = _load();

  ({double latitude, double longitude})? _position;
  List<StoreLocation> _nearbyStores = [];
  bool _isLoadingLocation = false;
  String? _locationMessage;

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
    final nearby = await widget.storeLocatorService.findNearby(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _position = position;
      _nearbyStores = nearby;
      _isLoadingLocation = false;
      _locationMessage = nearby.isEmpty
          ? 'Fant ingen butikker i nærheten akkurat nå (eller kunne ikke hente butikkposisjoner).'
          : null;
    });
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
    for (final category in categories) {
      final items = await widget.itemService.watchItems(widget.uid, widget.listId, category.id).first;
      itemNames.addAll(items.map((i) => i.name));
    }
    final analysis = await widget.cheapestStoreService.analyze(itemNames);
    return _Loaded(itemNames, analysis);
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

  Widget _buildSplitTab(ShoppingSplit split, List<StoreTotal> singleStoreTotals) {
    if (split.assignments.isEmpty) {
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

    final byStore = split.assignmentsByStore;
    final savings = _computeSavings(split, singleStoreTotals);
    final savingsItemsLabel = savings == null
        ? ''
        : savings.overlapCount == savings.listItemCount
            ? 'alle dine ${savings.listItemCount} varer'
            : 'de ${savings.overlapCount} av dine ${savings.listItemCount} varer som også finnes';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        for (final entry in byStore.entries) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
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
          ),
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
            Text('Totalt · ${byStore.length} butikker', style: Theme.of(context).textTheme.titleMedium),
            Text('${split.total.toStringAsFixed(2)} kr', style: Theme.of(context).textTheme.titleMedium),
          ],
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
              Tab(text: 'Flere butikker'),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Viser avstand fra deg til nærmeste butikk av hvert slag',
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
                      _buildSplitTab(loaded.analysis.split, loaded.analysis.storeTotals),
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
