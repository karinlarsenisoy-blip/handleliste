import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/shopping_split.dart';
import '../services/item_service.dart';

/// The confirmed, locked-in version of a "Handletur" plan. Once the user
/// taps "Bekreft rute" on the Handletur tab, the stops and item-per-store
/// assignments are handed here as a snapshot — this screen never re-sorts
/// or re-splits itself while someone is standing in a store with their
/// phone out, even if their position or the search radius would otherwise
/// change the plan. That stability is the whole point of "confirming" a
/// route first.
///
/// Checking an item off calls [ItemService.toggleItem] for real, so it's
/// reflected back on the original list — not just a checkbox that forgets
/// itself when this screen is closed.
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({
    super.key,
    required this.uid,
    required this.listId,
    required this.listName,
    required this.stops,
    required this.itemLookup,
    required this.itemService,
  });

  final String uid;
  final String listId;
  final String listName;
  final List<MapEntry<String, List<ItemAssignment>>> stops;
  final Map<String, ({Item item, String categoryId})> itemLookup;
  final ItemService itemService;

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final Set<String> _checkedNames = {};

  Future<void> _toggle(String itemName) async {
    setState(() {
      if (!_checkedNames.add(itemName)) _checkedNames.remove(itemName);
    });

    final lookup = widget.itemLookup[itemName];
    if (lookup == null) return;
    await widget.itemService.toggleItem(widget.uid, widget.listId, lookup.categoryId, lookup.item);
  }

  @override
  Widget build(BuildContext context) {
    final totalItemCount = widget.stops.fold<int>(0, (sum, stop) => sum + stop.value.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${_checkedNames.length} av $totalItemCount varer i kurven',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (var stopIndex = 0; stopIndex < widget.stops.length; stopIndex++) ...[
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(radius: 11, child: Text('${stopIndex + 1}', style: const TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  Text(widget.stops[stopIndex].key, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            for (final assignment in widget.stops[stopIndex].value)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                value: _checkedNames.contains(assignment.itemName),
                onChanged: (_) => _toggle(assignment.itemName),
                title: Text(
                  assignment.itemName,
                  style: _checkedNames.contains(assignment.itemName)
                      ? TextStyle(decoration: TextDecoration.lineThrough, color: Theme.of(context).disabledColor)
                      : null,
                ),
                secondary: Text('${assignment.price.toStringAsFixed(2)} kr'),
              ),
          ],
        ],
      ),
    );
  }
}
