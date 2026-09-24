import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/email_typo_checker.dart';

/// The Firebase project's own auto-generated "Web client" OAuth id (not a
/// secret — same category as a Firebase API key, see main.dart's Sentry DSN
/// comment for why that's fine). On native platforms, `signInWithPopup`
/// (below) doesn't exist at all — there's no browser popup to show — so
/// Google sign-in there goes through the native Google Sign-In SDK instead,
/// which needs this id as `serverClientId` to get back a Firebase-verifiable
/// ID token rather than just an on-device account handle.
const _googleWebClientId = '87233152428-tkff5ts9fsq5bs73vi6tkhgi7ogp5i1e.apps.googleusercontent.com';

/// [GoogleSignIn.initialize] must be called exactly once per app process and
/// awaited before any other call on the singleton — but this screen can be
/// built more than once (e.g. reached again from a different guest gate), so
/// this is memoized at the top level rather than redone in initState.
Future<void>? _googleSignInInitFuture;
Future<void> _ensureGoogleSignInInitialized() {
  return _googleSignInInitFuture ??= GoogleSignIn.instance.initialize(serverClientId: _googleWebClientId);
}

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
    if (_formKey.currentState?.validate() != true) return;

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
      _closeIfPushed();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Noe gikk galt. Prøv igjen.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// When this screen was reached from a guest-gated screen (pushed on top
  /// of the guest's HomeShell) rather than shown as AuthGate's own base
  /// route, pop it after a successful sign-in so the caller's screen —
  /// already rebuilt underneath with the new, non-anonymous uid — becomes
  /// visible again. A no-op when this *is* the base route (nothing to pop).
  void _closeIfPushed() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (kIsWeb) {
        // signInWithPopup only exists on web — there's no browser to pop a
        // window over on Android/iOS, which is why it silently did nothing
        // there before this platform split existed.
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        await _ensureGoogleSignInInitialized();
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      _closeIfPushed();
    } on GoogleSignInException catch (e) {
      // The user closing the account picker isn't an error worth surfacing.
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _errorMessage = 'Noe gikk galt med Google-innlogging. Prøv igjen.');
      }
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
