import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';

/// Not a secret — a Sentry DSN only lets a client *send* error reports to
/// this project, the same way any analytics key works; Sentry's own docs
/// say it's fine to ship in client code. Reports real crashes/exceptions
/// from real users straight to https://ktk-3o.sentry.io, which is the only
/// way we'd otherwise find out about something like the blank-screen boot
/// hang this session found — nobody was going to email us about that.
const _sentryDsn = 'https://2e63bcf3154b8489a7d29a588c6f174a@o4512124914499584.ingest.de.sentry.io/4512124933767248';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Only report from real (release) builds — a local `flutter run` during
  // development would otherwise flood the same dashboard with noise that
  // isn't a real user's experience.
  if (kReleaseMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(const HandlelisteApp()),
    );
  } else {
    runApp(const HandlelisteApp());
  }
}

class HandlelisteApp extends StatelessWidget {
  const HandlelisteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handleliste',
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
