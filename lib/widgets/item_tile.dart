import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/item_service.dart';
import '../theme.dart';
import 'item_edit_dialog.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.uid,
    required this.listId,
    required this.item,
    required this.itemService,
  });

  final String uid;
  final String listId;
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
    final data = await itemService.deleteItem(uid, listId, item);

    messenger.showSnackBar(
      SnackBar(
        content: Text('«$name» ble slettet'),
        action: SnackBarAction(
          label: 'ANGRE',
          onPressed: () => itemService.restoreItem(uid, listId, item.id, data),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// A circular checkbox that fills with the app's accent color when
  /// checked, matching the "Fersk" design mockup's row style — the default
  /// square Material [Checkbox] was never brought in line with the rest of
  /// the app's rounded look.
  Widget _buildCheckCircle(BuildContext context) {
    final accent = AppTheme.savingsAccent;
    return InkWell(
      key: Key('check-${item.id}'),
      customBorder: const CircleBorder(),
      onTap: () => itemService.toggleItem(uid, listId, item),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: item.isChecked ? accent : Colors.transparent,
          border: Border.all(
            color: item.isChecked ? accent : Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        child: item.isChecked
            ? Icon(Icons.check, size: 16, color: AppTheme.onSavingsAccent)
            : null,
      ),
    );
  }

  /// The item's photo when it has one (only set when it was added by
  /// picking a suggestion, see [Item.imageUrl]'s doc) — otherwise a plain
  /// placeholder, so a row is never left with no leading visual at all just
  /// because it was typed as free text rather than picked from a list.
  Widget _buildThumbnail(BuildContext context) {
    const size = 40.0;
    if (item.imageUrl == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.shopping_basket_outlined, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        item.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
          radius: size / 2,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.shopping_basket_outlined, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      decoration: item.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
      color: item.isChecked ? Theme.of(context).disabledColor : null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteItem(context),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCheckCircle(context),
                const SizedBox(width: 10),
                _buildThumbnail(context),
              ],
            ),
            title: Text(item.name, style: titleStyle),
            subtitle: item.note == null ? null : Text(item.note!, style: titleStyle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_quantityLabel, style: Theme.of(context).textTheme.bodyMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Rediger vare',
                  onPressed: () => _editItem(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
