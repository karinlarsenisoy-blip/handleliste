import 'package:flutter/material.dart';

import '../models/store_total.dart';
import '../services/category_service.dart';
import '../services/cheapest_store_service.dart';
import '../services/item_service.dart';

/// Shows which store is cheapest for everything on one shopping list — v1
/// of the "Finn billigst" feature: ranks single stores by total price
/// across whatever items we have a known price for there, using both our
/// own crowdsourced prices and Kassalapp. See CheapestStoreService for why
/// it doesn't yet try splitting the list across two stores.
class CheapestStoreScreen extends StatefulWidget {
  CheapestStoreScreen({
    super.key,
    required this.uid,
    required this.listId,
    required this.listName,
    CategoryService? categoryService,
    ItemService? itemService,
    CheapestStoreService? cheapestStoreService,
  })  : categoryService = categoryService ?? CategoryService(),
        itemService = itemService ?? ItemService(),
        cheapestStoreService = cheapestStoreService ?? CheapestStoreService();

  final String uid;
  final String listId;
  final String listName;
  final CategoryService categoryService;
  final ItemService itemService;
  final CheapestStoreService cheapestStoreService;

  @override
  State<CheapestStoreScreen> createState() => _CheapestStoreScreenState();
}

class _Result {
  _Result(this.itemCount, this.totals);
  final int itemCount;
  final List<StoreTotal> totals;
}

class _CheapestStoreScreenState extends State<CheapestStoreScreen> {
  late final Future<_Result> _future = _load();

  Future<_Result> _load() async {
    final categories = await widget.categoryService.watchCategories(widget.uid, widget.listId).first;
    final itemNames = <String>[];
    for (final category in categories) {
      final items = await widget.itemService.watchItems(widget.uid, widget.listId, category.id).first;
      itemNames.addAll(items.map((i) => i.name));
    }
    final totals = await widget.cheapestStoreService.findCheapestStores(itemNames);
    return _Result(itemNames.length, totals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Billigst for «${widget.listName}»')),
      body: FutureBuilder<_Result>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
          }

          final result = snapshot.data!;
          if (result.itemCount == 0) {
            return const Center(child: Text('Listen er tom — legg til varer først.'));
          }
          if (result.totals.isEmpty) {
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
            itemCount: result.totals.length,
            itemBuilder: (context, index) {
              final storeTotal = result.totals[index];
              final isCheapest = index == 0;
              return Card(
                color: isCheapest ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: isCheapest ? const Icon(Icons.emoji_events_outlined) : null,
                  title: Text(storeTotal.storeName, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text('${storeTotal.matchedItemCount} av ${storeTotal.totalItemCount} varer funnet'),
                  trailing: Text(
                    '${storeTotal.total.toStringAsFixed(2)} kr',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
