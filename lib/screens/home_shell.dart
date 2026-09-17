import 'package:flutter/material.dart';

import 'lists_page.dart';
import 'receipts_page.dart';

/// Top-level shell shown once signed in: switches between the shopping
/// lists and the receipts section. Each tab owns its own Scaffold/AppBar.
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
          ListsPage(uid: widget.uid),
          ReceiptsPage(uid: widget.uid),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Lister'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Kvitteringer'),
        ],
      ),
    );
  }
}
