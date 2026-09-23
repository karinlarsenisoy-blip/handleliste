import 'package:flutter/material.dart';

import '../services/chain_preferences_service.dart';
import '../services/cheapest_store_service.dart';
import '../services/item_service.dart';
import '../services/list_service.dart';
import '../services/receipt_service.dart';
import '../theme.dart';
import '../widgets/guest_gate.dart';
import '../widgets/list_picker.dart';
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
    required this.isAnonymous,
    CheapestStoreService? cheapestStoreService,
    ReceiptService? receiptService,
    ListService? listService,
    ItemService? itemService,
    ChainPreferencesService? chainPreferencesService,
  })  : cheapestStoreService = cheapestStoreService ?? CheapestStoreService(),
        receiptService = receiptService ?? ReceiptService(),
        listService = listService ?? ListService(),
        itemService = itemService ?? ItemService(),
        chainPreferencesService = chainPreferencesService ?? ChainPreferencesService();

  final String uid;
  final bool isAnonymous;
  final CheapestStoreService cheapestStoreService;
  final ReceiptService receiptService;
  final ListService listService;
  final ItemService itemService;
  final ChainPreferencesService chainPreferencesService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

typedef _StorePrice = ({String storeName, num price, DateTime lastObservedAt});

/// A small, fixed color per well-known chain so a result card reads at a
/// glance ("that's the green one, Kiwi") instead of every row looking the
/// same — a deliberately simple stand-in for real chain logos, which we
/// don't have redistribution rights to bundle into the app.
const _storeColors = {
  'Kiwi': Color(0xFF2E9E4F),
  'Rema 1000': Color(0xFF1F5FBF),
  'Meny': Color(0xFFC0142B),
  'Coop Extra': Color(0xFF0F6B3C),
  'Coop Mega': Color(0xFF0F6B3C),
  'Coop Prix': Color(0xFF0F6B3C),
  'Coop Obs': Color(0xFF0F6B3C),
  'Spar': Color(0xFF6B8E23),
  'Bunnpris': Color(0xFF7A4FBF),
  'Joker': Color(0xFFE08A00),
};

Color _storeColor(String storeName) => _storeColors[storeName] ?? const Color(0xFF1B5E63);

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
    final excluded = await widget.chainPreferencesService.getExcludedStoreNames();
    if (!mounted) return;
    setState(() {
      _results = excluded.isEmpty ? results : results.where((r) => !excluded.contains(r.storeName)).toList();
      _isSearching = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openOrGate(BuildContext context, {required String guestMessage, required WidgetBuilder builder}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: widget.isAnonymous ? (context) => GuestGateScreen(message: guestMessage) : builder,
      ),
    );
  }

  Future<void> _addSearchedItemToList() async {
    final name = _searchedName;
    if (name == null) return;

    if (widget.isAnonymous) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GuestGateScreen(message: 'legge varer i en handleliste')),
      );
      return;
    }

    final lists = await widget.listService.watchLists(widget.uid).first;
    if (!mounted) return;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Du har ingen lister ennå — lag en først.')));
      return;
    }

    final list = await pickList(context, lists);
    if (list == null || !mounted) return;

    await widget.itemService.addItem(widget.uid, list.id, name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name lagt til i «${list.name}»')),
    );
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
                    leading: CircleAvatar(
                      backgroundColor: _storeColor(result.storeName),
                      foregroundColor: Colors.white,
                      child: Text(
                        result.storeName[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(result.storeName),
                    subtitle: Text(_freshnessLabel(result.lastObservedAt)),
                    trailing: Text(
                      '${result.price.toStringAsFixed(2)} kr',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
            // Shown regardless of whether a price was found — you might not
            // have any price data for this item yet, but you should still
            // be able to add it to a list, same as typing it in there
            // directly would let you do.
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addSearchedItemToList,
                icon: const Icon(Icons.add),
                label: Text('Legg «$_searchedName» i en handleliste'),
              ),
            ),
          ],
          const Divider(height: 32),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.camera_alt_outlined),
              ),
              title: const Text('Skann en kvittering'),
              subtitle: const Text('Bidra anonymt til prisene alle ser'),
              onTap: () => _openOrGate(
                context,
                guestMessage: 'skanne og lagre kvitteringer',
                builder: (context) => AddReceiptScreen(uid: widget.uid, receiptService: widget.receiptService),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.savingsAccent.withValues(alpha: 0.12),
                foregroundColor: AppTheme.savingsAccent,
                child: const Icon(Icons.mic_none),
              ),
              title: const Text('Si varenavn til en liste'),
              subtitle: const Text('Si varenavn ett og ett — fungerer i Chrome/Edge'),
              onTap: () => _openOrGate(
                context,
                guestMessage: 'legge varer i en handleliste',
                builder: (context) => VoiceListEntryScreen(uid: widget.uid),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
