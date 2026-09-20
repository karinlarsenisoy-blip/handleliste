import 'package:flutter/material.dart';

import '../services/cheapest_store_service.dart';
import '../services/receipt_service.dart';
import '../widgets/product_name_field.dart';
import 'add_receipt_screen.dart';
import 'profile_screen.dart';
import 'voice_list_entry_screen.dart';

/// The app's front page: search is the very first thing you can do, since
/// "which store is this cheapest at right now" is the whole point of
/// Handleliste — not a browsable catalog or "this week's deals" section
/// (see project notes on why: no reliable data for either, and it would
/// undercut the point of having just removed categories/folders from
/// lists). A shortcut to capturing a receipt lives here too, since that's
/// the input that makes everything else in the app useful.
class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    required this.uid,
    CheapestStoreService? cheapestStoreService,
    ReceiptService? receiptService,
  })  : cheapestStoreService = cheapestStoreService ?? CheapestStoreService(),
        receiptService = receiptService ?? ReceiptService();

  final String uid;
  final CheapestStoreService cheapestStoreService;
  final ReceiptService receiptService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

typedef _StorePrice = ({String storeName, num price, DateTime lastObservedAt});

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<_StorePrice>? _results;
  String? _searchedName;
  bool _isSearching = false;

  String _freshnessLabel(DateTime lastObservedAt) {
    final age = DateTime.now().difference(lastObservedAt);
    if (age.inHours < 24) return 'Sett i dag';
    if (age.inDays == 1) return 'Sett i går';
    return 'Sett for ${age.inDays} dager siden';
  }

  Future<void> _search(String name, {String? imageUrl}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchedName = trimmed;
      _results = null;
    });
    final results = await widget.cheapestStoreService.pricesForItem(trimmed);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handleliste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen(uid: widget.uid)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Søk etter en vare, se billigst akkurat nå', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ProductNameField(
            controller: _searchController,
            hintText: 'F.eks. melk, bananer, kjøttdeig...',
            onSubmitted: _search,
          ),
          if (_isSearching) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_results != null) ...[
            const SizedBox(height: 12),
            if (_results!.isEmpty)
              Text('Fant ingen kjente priser for «$_searchedName» ennå.')
            else
              for (final result in _results!)
                Card(
                  child: ListTile(
                    title: Text(result.storeName),
                    subtitle: Text(_freshnessLabel(result.lastObservedAt)),
                    trailing: Text(
                      '${result.price.toStringAsFixed(2)} kr',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
          ],
          const Divider(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Skann en kvittering'),
              subtitle: const Text('Bidra anonymt til prisene alle ser'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddReceiptScreen(uid: widget.uid, receiptService: widget.receiptService),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Si varenavn til en liste'),
              subtitle: const Text('Si varenavn ett og ett — fungerer i Chrome/Edge'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VoiceListEntryScreen(uid: widget.uid)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
