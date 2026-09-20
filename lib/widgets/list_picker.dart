import 'package:flutter/material.dart';

import '../models/shopping_list.dart';

/// A bottom sheet for picking one of the user's shopping lists — shared by
/// any flow that needs to ask "which list?" (Favoritter's "legg til i
/// liste", voice item entry, ...).
Future<ShoppingList?> pickList(
  BuildContext context,
  List<ShoppingList> lists, {
  String title = 'Legg til i hvilken liste?',
}) {
  return showModalBottomSheet<ShoppingList>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
