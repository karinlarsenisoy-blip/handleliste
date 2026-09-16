import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import '../services/item_service.dart';
import '../widgets/category_tile.dart';

/// The content of a single list (tab): an "add category" field and the
/// list of that list's categories. Rendered inside a [TabBarView] by
/// ListsPage, which owns the surrounding Scaffold/AppBar/TabBar.
class CategoriesView extends StatefulWidget {
  const CategoriesView({
    super.key,
    required this.uid,
    required this.listId,
    required this.categoryService,
    required this.itemService,
  });

  final String uid;
  final String listId;
  final CategoryService categoryService;
  final ItemService itemService;

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  void _addCategory() {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    widget.categoryService.addCategory(widget.uid, widget.listId, name);
    _newCategoryController.clear();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
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
                child: TextField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(
                    hintText: 'Ny kategori...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addCategory,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Category>>(
            stream: widget.categoryService.watchCategories(widget.uid, widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
              }

              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return const Center(
                  child: Text('Ingen kategorier ennå — legg til en over!'),
                );
              }

              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: categories.length,
                onReorderItem: (oldIndex, newIndex) {
                  final reordered = List.of(categories);
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);
                  widget.categoryService.reorderCategories(widget.uid, widget.listId, reordered);
                },
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return CategoryTile(
                    key: ValueKey(category.id),
                    index: index,
                    uid: widget.uid,
                    listId: widget.listId,
                    category: category,
                    categoryService: widget.categoryService,
                    itemService: widget.itemService,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
