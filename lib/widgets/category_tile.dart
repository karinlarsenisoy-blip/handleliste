import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/item.dart';
import '../services/category_service.dart';
import '../services/item_service.dart';
import 'item_tile.dart';
import 'product_name_field.dart';

class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.uid,
    required this.listId,
    required this.index,
    required this.category,
    required this.categoryService,
    required this.itemService,
  });

  final String uid;
  final String listId;
  final int index;
  final Category category;
  final CategoryService categoryService;
  final ItemService itemService;

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  final TextEditingController _newItemController = TextEditingController();

  void _addItem({String? imageUrl}) {
    final name = _newItemController.text.trim();
    if (name.isEmpty) return;
    widget.itemService.addItem(widget.uid, widget.listId, widget.category.id, name, imageUrl: imageUrl);
    _newItemController.clear();
  }

  Future<void> _renameCategory() async {
    final controller = TextEditingController(text: widget.category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gi kategorien nytt navn'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      widget.categoryService.renameCategory(widget.uid, widget.listId, widget.category.id, newName);
    }
  }

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slette kategori?'),
        content: Text('Dette sletter «${widget.category.name}» og alle varene i den.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final categoryName = widget.category.name;
    final categoryId = widget.category.id;
    final snapshot = await widget.categoryService.deleteCategory(widget.uid, widget.listId, categoryId);

    messenger.showSnackBar(
      SnackBar(
        content: Text('«$categoryName» ble slettet'),
        action: SnackBarAction(
          label: 'ANGRE',
          onPressed: () => widget.categoryService.restoreCategory(
            widget.uid,
            widget.listId,
            categoryId,
            snapshot,
          ),
        ),
        duration: const Duration(seconds: 6),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.drag_handle),
              ),
            ),
            Expanded(
              child: Text(
                widget.category.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Endre navn',
              onPressed: _renameCategory,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Slett kategori',
              onPressed: _deleteCategory,
            ),
          ],
        ),
        children: [
          StreamBuilder<List<Item>>(
            stream: widget.itemService.watchItems(widget.uid, widget.listId, widget.category.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ingen varer i denne kategorien ennå'),
                  ),
                );
              }
              return Column(
                children: items
                    .map((item) => ItemTile(
                          uid: widget.uid,
                          listId: widget.listId,
                          categoryId: widget.category.id,
                          item: item,
                          itemService: widget.itemService,
                        ))
                    .toList(),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ProductNameField(
                    controller: _newItemController,
                    hintText: 'Ny vare i denne kategorien...',
                    onSubmitted: (_, {imageUrl}) => _addItem(imageUrl: imageUrl),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
