import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/item_tile.dart';
import '../widgets/product_name_field.dart';
import 'cheapest_store_screen.dart';

/// The content of a single list (tab): an "add item" field and a flat list
/// of that list's items — deliberately no category/folder level (see
/// ItemService's doc for why). Rendered inside a [TabBarView] by ListsPage,
/// which owns the surrounding Scaffold/AppBar/TabBar.
class ListItemsView extends StatefulWidget {
  const ListItemsView({
    super.key,
    required this.uid,
    required this.listId,
    required this.listName,
    required this.itemService,
  });

  final String uid;
  final String listId;
  final String listName;
  final ItemService itemService;

  @override
  State<ListItemsView> createState() => _ListItemsViewState();
}

class _ListItemsViewState extends State<ListItemsView> with AutomaticKeepAliveClientMixin {
  final TextEditingController _newItemController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  void _addItem({String? imageUrl}) {
    final name = _newItemController.text.trim();
    if (name.isEmpty) return;
    widget.itemService.addItem(widget.uid, widget.listId, name, imageUrl: imageUrl);
    _newItemController.clear();
  }

  void _openCheapestStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheapestStoreScreen(
          uid: widget.uid,
          listId: widget.listId,
          listName: widget.listName,
          itemService: widget.itemService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ProductNameField(
                  controller: _newItemController,
                  hintText: 'Ny vare...',
                  onSubmitted: (_, {imageUrl, fromSuggestion = false}) => _addItem(imageUrl: imageUrl),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _addItem, child: const Icon(Icons.add)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Item>>(
            stream: widget.itemService.watchItems(widget.uid, widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('Ingen varer ennå — legg til en over!'));
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => ItemTile(
                  key: ValueKey(items[index].id),
                  uid: widget.uid,
                  listId: widget.listId,
                  item: items[index],
                  itemService: widget.itemService,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _openCheapestStore,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.savingsAccent,
                foregroundColor: AppTheme.onSavingsAccent,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Finn billigst'),
            ),
          ),
        ),
      ],
    );
  }
}
