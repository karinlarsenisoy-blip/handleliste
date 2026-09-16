import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/item_service.dart';
import 'item_edit_dialog.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.uid,
    required this.listId,
    required this.categoryId,
    required this.item,
    required this.itemService,
  });

  final String uid;
  final String listId;
  final String categoryId;
  final Item item;
  final ItemService itemService;

  String get _quantityLabel {
    final q = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    return item.unit == null ? q : '$q ${item.unit}';
  }

  Future<void> _editItem(BuildContext context) async {
    final result = await showItemEditDialog(
      context,
      title: 'Rediger vare',
      initialName: item.name,
      initialQuantity: item.quantity,
      initialUnit: item.unit,
      initialNote: item.note,
    );
    if (result != null && result.name.isNotEmpty) {
      itemService.updateItem(
        uid,
        listId,
        categoryId,
        item,
        name: result.name,
        quantity: result.quantity,
        unit: result.unit,
        note: result.note,
      );
    }
  }

  Future<void> _deleteItem(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = item.name;
    final data = await itemService.deleteItem(uid, listId, categoryId, item);

    messenger.showSnackBar(
      SnackBar(
        content: Text('«$name» ble slettet'),
        action: SnackBarAction(
          label: 'ANGRE',
          onPressed: () => itemService.restoreItem(uid, listId, categoryId, item.id, data),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      decoration: item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
      color: item.isChecked ? Theme.of(context).disabledColor : null,
    );

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(context),
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isChecked,
          onChanged: (_) => itemService.toggleItem(uid, listId, categoryId, item),
        ),
        title: Text(item.name, style: titleStyle),
        subtitle: item.note == null ? null : Text(item.note!, style: titleStyle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_quantityLabel, style: Theme.of(context).textTheme.bodyMedium),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Rediger vare',
              onPressed: () => _editItem(context),
            ),
          ],
        ),
      ),
    );
  }
}
