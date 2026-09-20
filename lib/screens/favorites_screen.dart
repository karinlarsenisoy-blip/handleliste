import 'package:flutter/material.dart';

import '../models/favorite_item.dart';
import '../models/shopping_list.dart';
import '../services/favorites_service.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';

/// "What do you actually keep buying" — built from receipt history rather
/// than list history, so it reflects real purchases, not just things that
/// were once typed into a list. The motivation for the user to scan
/// receipts at all is that doing so is what makes this page useful.
class FavoritesScreen extends StatefulWidget {
  FavoritesScreen({
    super.key,
    required this.uid,
    FavoritesService? favoritesService,
    ListService? listService,
    ItemService? itemService,
  })  : favoritesService = favoritesService ?? FavoritesService(),
        listService = listService ?? ListService(),
        itemService = itemService ?? ItemService();

  final String uid;
  final FavoritesService favoritesService;
  final ListService listService;
  final ItemService itemService;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final Future<List<FavoriteItem>> _future = widget.favoritesService.mostPurchased(widget.uid);

  String _lastPurchasedLabel(DateTime date) {
    final age = DateTime.now().difference(date);
    if (age.inHours < 24) return 'sist kjøpt i dag';
    if (age.inDays == 1) return 'sist kjøpt i går';
    if (age.inDays < 30) return 'sist kjøpt for ${age.inDays} dager siden';
    return 'sist kjøpt for ${(age.inDays / 30).round()} måneder siden';
  }

  Future<ShoppingList?> _pickList(List<ShoppingList> lists) {
    return showModalBottomSheet<ShoppingList>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Legg til i hvilken liste?', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final list in lists)
              ListTile(
                title: Text(list.name),
                onTap: () => Navigator.pop(context, list),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToList(FavoriteItem favorite) async {
    final lists = await widget.listService.watchLists(widget.uid).first;
    if (!mounted) return;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Du har ingen lister ennå — lag en først.')));
      return;
    }

    final list = await _pickList(lists);
    if (list == null || !mounted) return;

    await widget.itemService.addItem(widget.uid, list.id, favorite.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${favorite.name} lagt til i «${list.name}»')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritter')),
      body: FutureBuilder<List<FavoriteItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
          }

          final favorites = snapshot.data!;
          if (favorites.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Ingen favoritter ennå. Skann eller lim inn kvitteringer for varene du kjøper — '
                  'kjøper du samme vare på minst to kvitteringer, dukker den opp her.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${favorite.purchaseCount}')),
                  title: Text(favorite.name),
                  subtitle: Text(
                    'Kjøpt ${favorite.purchaseCount} ganger · ${_lastPurchasedLabel(favorite.lastPurchasedAt)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Legg til i en liste',
                    onPressed: () => _addToList(favorite),
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
