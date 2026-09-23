import 'package:flutter/material.dart';

import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../services/cheapest_store_service.dart';
import '../services/receipt_service.dart';
import 'add_receipt_screen.dart';

/// Lists the user's saved receipts (newest first) and lets them add a new
/// one. This is purely the personal data-collection side for now — turning
/// these into a cross-store price comparison is a later round.
class ReceiptsPage extends StatelessWidget {
  ReceiptsPage({
    super.key,
    required this.uid,
    ReceiptService? receiptService,
    CheapestStoreService? cheapestStoreService,
  })  : receiptService = receiptService ?? ReceiptService(),
        cheapestStoreService = cheapestStoreService ?? CheapestStoreService();

  final String uid;
  final ReceiptService receiptService;
  final CheapestStoreService cheapestStoreService;

  Future<void> _deleteReceipt(BuildContext context, Receipt receipt) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await receiptService.deleteReceipt(uid, receipt.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Kvittering fra ${receipt.storeName} ble slettet'),
        action: SnackBarAction(
          label: 'ANGRE',
          onPressed: () => receiptService.restoreReceipt(uid, receipt.id, data),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kvitteringer')),
      body: StreamBuilder<List<Receipt>>(
        stream: receiptService.watchReceipts(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Noe gikk galt: ${snapshot.error}'));
          }

          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return const Center(
              child: Text('Ingen kvitteringer ennå — trykk + for å legge til én'),
            );
          }

          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return Dismissible(
                key: ValueKey(receipt.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _deleteReceipt(context, receipt),
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: _ReceiptComparisonTile(receipt: receipt, cheapestStoreService: cheapestStoreService),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddReceiptScreen(uid: uid, receiptService: receiptService),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

typedef _CheaperElsewhere = ({num price, String storeName});

/// One receipt's expandable row — checks, the first time it's opened,
/// whether any of its items are known to be cheaper somewhere else *right
/// now* (not "at the time of purchase": there's no price-history-at-a-date
/// query, only current known prices, so this is framed as "nettopp nå" —
/// close to what SeSum's own "ingen av varene var billigere andre steder"
/// check does, and reuses the exact same [CheapestStoreService] the rest of
/// the app already trusts, rather than a second comparison path).
class _ReceiptComparisonTile extends StatefulWidget {
  const _ReceiptComparisonTile({required this.receipt, required this.cheapestStoreService});

  final Receipt receipt;
  final CheapestStoreService cheapestStoreService;

  @override
  State<_ReceiptComparisonTile> createState() => _ReceiptComparisonTileState();
}

class _ReceiptComparisonTileState extends State<_ReceiptComparisonTile> {
  Future<Map<String, _CheaperElsewhere>>? _cheaperElsewhere;

  Future<Map<String, _CheaperElsewhere>> _checkPrices() async {
    final result = <String, _CheaperElsewhere>{};
    final entries = await Future.wait(widget.receipt.items.map((item) async {
      final prices = await widget.cheapestStoreService.pricesForItem(item.name);
      if (prices.isEmpty) return null;
      // The receipt stores the line's TOTAL, not a per-unit price — has to
      // be divided back down to compare against pricesForItem's per-unit
      // figures, same conversion contributeObservation itself does.
      final paidPerUnit = item.price / item.quantity;
      final cheapest = prices.first; // pricesForItem is already cheapest-first
      if (cheapest.price < paidPerUnit) {
        return MapEntry(item.name, (price: cheapest.price, storeName: cheapest.storeName));
      }
      return null;
    }));

    for (final entry in entries) {
      if (entry != null) result[entry.key] = entry.value;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return ExpansionTile(
      title: Text(receipt.storeName),
      subtitle: Text(
        '${receipt.purchasedAt.day}.${receipt.purchasedAt.month}.${receipt.purchasedAt.year} · '
        '${receipt.items.length} varer',
      ),
      trailing: Text('${receipt.total.toStringAsFixed(2)} kr'),
      onExpansionChanged: (expanded) {
        if (expanded && _cheaperElsewhere == null) {
          final future = _checkPrices();
          setState(() {
            _cheaperElsewhere = future;
          });
        }
      },
      children: [
        FutureBuilder<Map<String, _CheaperElsewhere>>(
          future: _cheaperElsewhere,
          builder: (context, snapshot) {
            final cheaperMap = snapshot.data;
            final isLoading = _cheaperElsewhere != null && snapshot.connectionState != ConnectionState.done;

            return Column(
              children: [
                if (isLoading)
                  const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2))
                else if (cheaperMap != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      cheaperMap.isEmpty
                          ? 'Ingen av varene var billigere andre steder nettopp nå.'
                          : '${cheaperMap.length} av ${receipt.items.length} varer er billigere andre steder nettopp nå.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                for (final item in receipt.items) _itemRow(item, cheaperMap?[item.name]),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _itemRow(ReceiptItem item, _CheaperElsewhere? cheaper) {
    return ListTile(
      dense: true,
      title: Text(item.name),
      subtitle: cheaper == null
          ? null
          : Builder(
              builder: (context) => Text(
                'Billigere hos ${cheaper.storeName}: ${cheaper.price.toStringAsFixed(2)} kr',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
      trailing: Text('${item.price.toStringAsFixed(2)} kr'),
    );
  }
}
