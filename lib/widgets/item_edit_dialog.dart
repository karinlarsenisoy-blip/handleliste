import 'package:flutter/material.dart';

class ItemEditResult {
  ItemEditResult(this.name, this.quantity, this.unit, this.note);
  final String name;
  final num quantity;
  final String? unit;
  final String? note;
}

/// Free-text units are common in a shopping list; this is just a shortlist
/// of the most frequent ones so the user rarely has to type it out.
const List<String?> unitChoices = [null, 'stk', 'kg', 'g', 'l', 'dl', 'pk', 'boks'];

Future<ItemEditResult?> showItemEditDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required num initialQuantity,
  required String? initialUnit,
  required String? initialNote,
}) {
  return showDialog<ItemEditResult>(
    context: context,
    builder: (context) => _ItemEditDialog(
      title: title,
      initialName: initialName,
      initialQuantity: initialQuantity,
      initialUnit: initialUnit,
      initialNote: initialNote,
    ),
  );
}

class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({
    required this.title,
    required this.initialName,
    required this.initialQuantity,
    required this.initialUnit,
    required this.initialNote,
  });

  final String title;
  final String initialName;
  final num initialQuantity;
  final String? initialUnit;
  final String? initialNote;

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote ?? '');
  late num _quantity = widget.initialQuantity;
  late String? _unit = widget.initialUnit;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _changeQuantity(num delta) {
    setState(() => _quantity = (_quantity + delta).clamp(0.5, 9999));
  }

  void _save() {
    Navigator.pop(
      context,
      ItemEditResult(
        _nameController.text.trim(),
        _quantity,
        _unit,
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Navn'),
            ),
            const SizedBox(height: 16),
            const Text('Antall'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _changeQuantity(-1),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    _quantity == _quantity.roundToDouble()
                        ? _quantity.toInt().toString()
                        : _quantity.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _changeQuantity(1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String?>(
                    value: _unit,
                    isExpanded: true,
                    hint: const Text('enhet'),
                    items: unitChoices
                        .map((u) => DropdownMenuItem(value: u, child: Text(u ?? '(ingen)')))
                        .toList(),
                    onChanged: (value) => setState(() => _unit = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Notat (valgfritt)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
        FilledButton(onPressed: _save, child: const Text('Lagre')),
      ],
    );
  }
}
