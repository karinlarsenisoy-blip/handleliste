import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'home_screen.dart';
import 'lists_page.dart';
import 'receipts_page.dart';

/// Top-level shell shown once signed in. Hjem is the front page (search +
/// quick actions — see HomeScreen's doc); Favoritter and Profil used to be
/// buried as small AppBar icons on the Lister tab, which read as a web
/// toolbar rather than an app — they're proper destinations/screens now.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid});

  final String uid;

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
          HomeScreen(uid: widget.uid),
          ListsPage(uid: widget.uid),
          ReceiptsPage(uid: widget.uid),
          FavoritesScreen(uid: widget.uid),
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
