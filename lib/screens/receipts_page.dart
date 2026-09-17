import 'package:flutter/material.dart';

import '../models/receipt.dart';
import '../services/receipt_service.dart';
import 'add_receipt_screen.dart';

/// Lists the user's saved receipts (newest first) and lets them add a new
/// one. This is purely the personal data-collection side for now — turning
/// these into a cross-store price comparison is a later round.
class ReceiptsPage extends StatelessWidget {
  ReceiptsPage({super.key, required this.uid, ReceiptService? receiptService})
      : receiptService = receiptService ?? ReceiptService();

  final String uid;
  final ReceiptService receiptService;

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
                child: ExpansionTile(
                  title: Text(receipt.storeName),
                  subtitle: Text(
                    '${receipt.purchasedAt.day}.${receipt.purchasedAt.month}.${receipt.purchasedAt.year} · '
                    '${receipt.items.length} varer',
                  ),
                  trailing: Text('${receipt.total.toStringAsFixed(2)} kr'),
                  children: receipt.items
                      .map((item) => ListTile(
                            dense: true,
                            title: Text(item.name),
                            trailing: Text('${item.price.toStringAsFixed(2)} kr'),
                          ))
                      .toList(),
                ),
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
