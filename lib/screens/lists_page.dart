import 'package:flutter/material.dart';

import '../models/shopping_list.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';
import 'list_items_view.dart';

/// Top-level screen: a row of tabs ("Ukehandel", "Bursdag", ...), each
/// showing its own independent flat list of items — no category/folder
/// level (see ItemService's doc for why). "Finn billigst" is a prominent
/// docked button on the list itself (see ListItemsView) since it's the
/// app's single biggest call-to-action; rename/delete stay tucked in one
/// overflow menu — Favoritter and Profil moved to HomeShell's own
/// navigation, since they aren't specific to one list.
class ListsPage extends StatefulWidget {
  ListsPage({
    super.key,
    required this.uid,
    ListService? listService,
    ItemService? itemService,
  })  : listService = listService ?? ListService(),
        itemService = itemService ?? ItemService();

  final String uid;
  final ListService listService;
  final ItemService itemService;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

enum _ListAction { rename, delete }

class _ListsPageState extends State<ListsPage> with TickerProviderStateMixin {
  TabController? _tabController;
  List<ShoppingList> _lists = [];

  void _syncTabController(List<ShoppingList> lists) {
    final sameIds = _lists.length == lists.length &&
        List.generate(lists.length, (i) => _lists[i].id == lists[i].id)
            .every((same) => same);
    _lists = lists;
    if (sameIds) return;

    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: lists.length,
      vsync: this,
      initialIndex: lists.isEmpty ? 0 : oldIndex.clamp(0, lists.length - 1),
    );
  }

  Future<String?> _promptForName({required String title, required String initialText}) {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  Future<void> _addList() async {
    final name = await _promptForName(title: 'Ny liste', initialText: '');
    if (name != null && name.isNotEmpty) {
      await widget.listService.addList(widget.uid, name);
    }
  }

  Future<void> _renameCurrentList(ShoppingList current) async {
    final name = await _promptForName(title: 'Gi listen nytt navn', initialText: current.name);
    if (name != null && name.isNotEmpty) {
      await widget.listService.renameList(widget.uid, current.id, name);
    }
  }

  Future<void> _deleteCurrentList(ShoppingList current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slette liste?'),
        content: Text('Dette sletter listen «${current.name}» og alt innholdet i den.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slett')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final listName = current.name;
    final snapshot = await widget.listService.deleteList(widget.uid, current.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('«$listName» ble slettet'),
        action: SnackBarAction(
          label: 'ANGRE',
          onPressed: () => widget.listService.restoreList(widget.uid, current.id, snapshot),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _handleListAction(_ListAction action, ShoppingList current) {
    switch (action) {
      case _ListAction.rename:
        _renameCurrentList(current);
      case _ListAction.delete:
        _deleteCurrentList(current);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShoppingList>>(
      stream: widget.listService.watchLists(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Noe gikk galt: ${snapshot.error}')));
        }

        final lists = snapshot.data ?? [];
        _syncTabController(lists);
        final current = lists.isEmpty ? null : lists[_tabController!.index.clamp(0, lists.length - 1)];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mine handlelister'),
            bottom: lists.isEmpty
                ? null
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: lists.map((l) => Tab(text: l.name)).toList(),
                  ),
            actions: [
              IconButton(icon: const Icon(Icons.add), tooltip: 'Ny liste', onPressed: _addList),
              if (current != null)
                PopupMenuButton<_ListAction>(
                  onSelected: (action) => _handleListAction(action, current),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ListAction.rename,
                      child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Endre navn')),
                    ),
                    PopupMenuItem(
                      value: _ListAction.delete,
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Slett liste')),
                    ),
                  ],
                ),
            ],
          ),
          body: lists.isEmpty
              ? const Center(
                  child: Text(
                    'Ingen lister ennå — trykk + for å legge til én (f.eks. «Ukehandel» eller «Bursdag»)',
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: lists
                      .map(
                        (list) => ListItemsView(
                          key: ValueKey(list.id),
                          uid: widget.uid,
                          listId: list.id,
                          listName: list.name,
                          itemService: widget.itemService,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
