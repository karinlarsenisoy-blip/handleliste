import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_shell.dart';
import 'sign_in_screen.dart';

/// Search (the whole point of Handleliste, see [HomeScreen]'s doc) needs no
/// account, so a first-time visitor is signed in anonymously in the
/// background instead of being made to log in before they can do anything —
/// [SignInScreen] is only reached later, from a screen that actually needs a
/// persistent account (see [GuestGateScreen]). If anonymous sign-in itself
/// fails — e.g. that provider isn't enabled yet in the Firebase console —
/// this falls back to showing [SignInScreen] directly rather than hanging on
/// a spinner forever.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _anonymousSignIn;
  bool _anonymousSignInFailed = false;

  void _ensureSignedIn() {
    _anonymousSignIn ??= _signInAnonymously();
  }

  Future<void> _signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      if (mounted) setState(() => _anonymousSignInFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          if (_anonymousSignInFailed) return const SignInScreen();
          _ensureSignedIn();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeShell(uid: user.uid, isAnonymous: user.isAnonymous);
      },
    );
  }
}
