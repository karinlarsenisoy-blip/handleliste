import 'package:flutter/material.dart';

import '../services/store_layout_service.dart';

/// Lets a user physically standing in a specific store branch capture its
/// real walk order by tapping their own list's categories in the order
/// they pass them — the lightweight alternative to filming the store: it
/// produces the same data (an ordered list of departments) without any
/// video/computer-vision work, and takes under a minute.
class MapStoreLayoutScreen extends StatefulWidget {
  MapStoreLayoutScreen({
    super.key,
    required this.branchId,
    required this.branchLabel,
    required this.chainName,
    required this.categoryNames,
    StoreLayoutService? storeLayoutService,
  }) : storeLayoutService = storeLayoutService ?? StoreLayoutService();

  final String branchId;
  final String branchLabel;
  final String chainName;
  final List<String> categoryNames;
  final StoreLayoutService storeLayoutService;

  @override
  State<MapStoreLayoutScreen> createState() => _MapStoreLayoutScreenState();
}

class _MapStoreLayoutScreenState extends State<MapStoreLayoutScreen> {
  final List<String> _ordered = [];
  bool _isSaving = false;

  List<String> get _remaining => widget.categoryNames.where((c) => !_ordered.contains(c)).toList();

  void _tap(String category) => setState(() => _ordered.add(category));

  void _undoLast() => setState(() {
        if (_ordered.isNotEmpty) _ordered.removeLast();
      });

  void _reset() => setState(_ordered.clear);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await widget.storeLayoutService.saveLayout(widget.branchId, widget.chainName, _ordered);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kartlegg ${widget.branchLabel}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gå gjennom butikken og trykk på kategoriene i den rekkefølgen du faktisk går forbi dem. '
              'Dette hjelper andre som handler her senere.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_ordered.isNotEmpty) ...[
                      Text('Rekkefølge så langt', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _ordered.length; i++) Chip(label: Text('${i + 1}. ${_ordered[i]}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _undoLast, child: const Text('Angre siste')),
                      const Divider(height: 24),
                    ],
                    if (_remaining.isNotEmpty) ...[
                      Text('Neste kategori du passerer', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in _remaining)
                            ActionChip(label: Text(category), onPressed: () => _tap(category)),
                        ],
                      ),
                    ] else
                      const Text('Alle kategoriene er plassert.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_ordered.isNotEmpty) TextButton(onPressed: _reset, child: const Text('Start på nytt')),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving || _ordered.isEmpty ? null : _save,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Lagre butikkoppsett'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
