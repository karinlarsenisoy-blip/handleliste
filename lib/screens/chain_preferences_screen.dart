import 'package:flutter/material.dart';

import '../models/store.dart';
import '../services/chain_preferences_service.dart';

/// Lets the user opt specific grocery chains out of price comparisons
/// (e.g. "I never shop at Meny, stop showing it"). See
/// [ChainPreferencesService]'s doc for why this is a local, per-device
/// preference rather than Firestore-backed.
class ChainPreferencesScreen extends StatefulWidget {
  ChainPreferencesScreen({super.key, ChainPreferencesService? service})
      : service = service ?? ChainPreferencesService();

  final ChainPreferencesService service;

  @override
  State<ChainPreferencesScreen> createState() => _ChainPreferencesScreenState();
}

class _ChainPreferencesScreenState extends State<ChainPreferencesScreen> {
  late Future<Set<String>> _excluded = widget.service.getExcludedStoreNames();

  Future<void> _toggle(String storeName, bool compare, Set<String> current) async {
    final updated = {...current};
    if (compare) {
      updated.remove(storeName);
    } else {
      updated.add(storeName);
    }
    await widget.service.setExcludedStoreNames(updated);
    setState(() => _excluded = Future.value(updated));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Butikker å sammenligne')),
      body: FutureBuilder<Set<String>>(
        future: _excluded,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final excluded = snapshot.data!;

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Skru av kjeder du aldri handler hos, så tar ikke søk og prissammenligning dem med.',
                ),
              ),
              for (final store in knownStores.where((s) => s.id != 'annet'))
                SwitchListTile(
                  title: Text(store.name),
                  value: !excluded.contains(store.name),
                  onChanged: (compare) => _toggle(store.name, compare, excluded),
                ),
            ],
          );
        },
      ),
    );
  }
}
