import 'package:flutter/material.dart';

import '../widgets/guest_gate.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'lists_page.dart';
import 'receipts_page.dart';

/// Top-level shell shown once signed in (including anonymously — see
/// AuthGate). Hjem is the front page (search + quick actions — see
/// HomeScreen's doc) and works for a guest; the other three tabs write
/// user data tied to the uid, which is only worth doing with a real,
/// recoverable account, so a guest sees [GuestGateScreen] there instead.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid, required this.isAnonymous});

  final String uid;
  final bool isAnonymous;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(uid: widget.uid, isAnonymous: widget.isAnonymous),
          widget.isAnonymous
              ? const GuestGateScreen(message: 'lagre og se handlelister')
              : ListsPage(uid: widget.uid),
          widget.isAnonymous
              ? const GuestGateScreen(message: 'lagre og se kvitteringer')
              : ReceiptsPage(uid: widget.uid),
          widget.isAnonymous
              ? const GuestGateScreen(message: 'samle favoritter fra kvitteringene dine')
              : FavoritesScreen(uid: widget.uid),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Hjem'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Lister'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Kvitteringer'),
          NavigationDestination(icon: Icon(Icons.star_outline), label: 'Favoritter'),
        ],
      ),
    );
  }
}
