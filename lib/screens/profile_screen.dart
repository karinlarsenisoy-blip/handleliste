import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/test_data_seeder.dart';
import 'sign_in_screen.dart';

/// Standard account/profile functionality: display name, email (read-only),
/// change password (via reset email), sign out, and account deletion
/// (GDPR). Reached from the account icon on [ListsPage].
class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key, required this.uid, AccountService? accountService})
      : accountService = accountService ?? AccountService();

  final String uid;
  final AccountService accountService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final TextEditingController _newEmailController = TextEditingController();
  bool _isSavingName = false;
  bool _isSendingReset = false;
  bool _isChangingEmail = false;

  @override
  void dispose() {
    _nameController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    setState(() => _isSavingName = true);
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name.isEmpty ? null : name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navn lagret')));
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('E-post for å bytte passord er sendt til $email')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? 'Kunne ikke sende e-post.')));
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _promptChangeEmail() async {
    _newEmailController.clear();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endre e-post'),
        content: TextField(
          controller: _newEmailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Ny e-post'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _newEmailController.text.trim()),
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
    if (newEmail == null || newEmail.isEmpty || !mounted) return;
    await _changeEmail(newEmail);
  }

  Future<void> _changeEmail(String newEmail) async {
    if (!newEmail.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Skriv inn en gyldig e-postadresse først.')));
      return;
    }

    setState(() => _isChangingEmail = true);
    try {
      await _sendEmailChangeVerification(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message ?? 'Kunne ikke endre e-post.')));
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final currentEmail = user?.email;
      if (currentEmail == null || !mounted) return;

      final password = await _promptForPassword();
      if (password == null || password.isEmpty || !mounted) return;

      try {
        await user!.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: currentEmail, password: password),
        );
        await _sendEmailChangeVerification(newEmail);
      } on FirebaseAuthException catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e2.message ?? 'Kunne ikke endre e-post.')));
        }
      }
    } finally {
      if (mounted) setState(() => _isChangingEmail = false);
    }
  }

  Future<void> _sendEmailChangeVerification(String newEmail) async {
    await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
    if (mounted) {
      _newEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bekreftelse sendt til $newEmail — trykk lenken der for å fullføre.')),
      );
    }
  }

  Future<void> _seedTestData() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Legger til testdata...')));
    await TestDataSeeder().seedAll(widget.uid);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Testdata lagt til: «Ukehandel» og «Hjem fra jobb», pluss noen testpriser.')),
      );
    }
  }

  Future<String?> _promptForPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bekreft passordet ditt'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Passord'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Bekreft'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slette konto?'),
        content: const Text(
          'Dette sletter kontoen din og ALT innhold permanent — alle lister, kategorier, '
          'varer og kvitteringer. Dette kan ikke angres.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Avbryt')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Slett konto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.accountService.deleteAccount();
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message ?? 'Kunne ikke slette kontoen.')));
        }
        return;
      }

      // Firebase krever nylig innlogging før en konto kan slettes.
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (email == null || !mounted) return;

      final password = await _promptForPassword();
      if (password == null || password.isEmpty || !mounted) return;

      try {
        await user!.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        await widget.accountService.deleteAccount();
        if (mounted) Navigator.pop(context);
      } on FirebaseAuthException catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e2.message ?? 'Kunne ikke slette kontoen.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Du bruker Handleliste som gjest — søk fungerer, men lister, kvitteringer '
                  'og favoritter krever en konto for å bli lagret.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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

    final email = FirebaseAuth.instance.currentUser?.email ?? '(ingen e-post)';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('E-post', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(email, style: Theme.of(context).textTheme.bodyLarge)),
              if (_isChangingEmail)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Endre e-post',
                  onPressed: _promptChangeEmail,
                ),
            ],
          ),
          const Divider(height: 40),
          Text('Visningsnavn', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            'Navnet appen viser for deg — helt valgfritt, kan være fornavnet ditt eller et kallenavn.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Visningsnavn'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSavingName ? null : _saveName,
              child: _isSavingName
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lagre navn'),
            ),
          ),
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_reset),
            title: const Text('Bytt passord'),
            subtitle: const Text('Sender en e-post med lenke for å sette nytt passord'),
            trailing: _isSendingReset
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _isSendingReset ? null : _sendPasswordReset,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Logg ut'),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.science_outlined),
            title: const Text('Legg til testdata (dev)'),
            onTap: _seedTestData,
          ),
          const Divider(height: 40),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever, color: errorColor),
            title: Text('Slett konto', style: TextStyle(color: errorColor)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
