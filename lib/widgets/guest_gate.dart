import 'package:flutter/material.dart';

import '../screens/sign_in_screen.dart';

/// Shown in place of a screen that needs a real, persistent account —
/// lists and receipts are tied to the signed-in uid, and an anonymous
/// session has no recovery path if the browser's storage is ever cleared,
/// so nothing that writes user data is offered to a guest. Search (the
/// [HomeScreen]) stays free precisely because it writes nothing.
class GuestGateScreen extends StatelessWidget {
  const GuestGateScreen({super.key, required this.message});

  /// What the user was trying to do, e.g. "lagre lister" — filled into
  /// "Opprett en konto for å {message}.".
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Opprett en konto for å $message',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Søk og prissammenligning er fritt tilgjengelig uten konto — dette er det eneste som krever en.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                ),
                child: const Text('Opprett konto eller logg inn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
