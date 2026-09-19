import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HandlelisteApp());
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
