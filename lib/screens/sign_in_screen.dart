import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/email_typo_checker.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _suggestedEmail;

  void _onEmailChanged(String value) {
    setState(() => _suggestedEmail = suggestEmailCorrection(value.trim()));
  }

  void _applySuggestedEmail() {
    if (_suggestedEmail == null) return;
    _emailController.text = _suggestedEmail!;
    _emailController.selection = TextSelection.collapsed(offset: _emailController.text.length);
    setState(() => _suggestedEmail = null);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      // Tells the browser/platform "the login just succeeded" — this is what
      // actually triggers the "Save password?" prompt in most browsers.
      TextInput.finishAutofillContext();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        setState(() => _errorMessage =
            'Du har allerede en konto med denne e-postadressen registrert med e-post/passord. '
            'Logg inn med passordet ditt i stedet.');
      } else {
        setState(() => _errorMessage = e.message ?? 'Noe gikk galt. Prøv igjen.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Opprett konto' : 'Logg inn'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'E-post'),
                          onChanged: _onEmailChanged,
                          validator: (value) => (value == null || !value.contains('@'))
                              ? 'Skriv inn en gyldig e-postadresse'
                              : null,
                        ),
                        if (_suggestedEmail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _applySuggestedEmail,
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                child: Text('Mente du $_suggestedEmail?'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: [
                            _isRegistering ? AutofillHints.newPassword : AutofillHints.password,
                          ],
                          decoration: const InputDecoration(labelText: 'Passord'),
                          validator: (value) => (value == null || value.length < 6)
                              ? 'Passordet må ha minst 6 tegn'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegistering ? 'Opprett konto' : 'Logg inn'),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _isRegistering = !_isRegistering),
                    child: Text(
                      _isRegistering
                          ? 'Har du allerede en konto? Logg inn'
                          : 'Ny bruker? Opprett konto',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('eller'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Logg inn med Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
