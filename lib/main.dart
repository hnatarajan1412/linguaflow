import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';


import 'package:linguaflow/firebase_options.dart';
import 'package:linguaflow/theme.dart';
import 'package:linguaflow/screens/auth_gate_mobile.dart' if (dart.library.js) 'package:linguaflow/screens/auth_gate_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture errors early to surface full stacks in the web console
  FlutterError.onError = (FlutterErrorDetails details) {
    // Always log the full error and stack
    // ignore: avoid_print
    print('[FlutterError] ${details.exceptionAsString()}');
    if (details.stack != null) {
      // ignore: avoid_print
      print('[FlutterError][stack] ${details.stack}');
    }
    FlutterError.presentError(details);
  };
  // Also capture framework-independent async errors
  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    // ignore: avoid_print
    print('[onError] $error');
    // ignore: avoid_print
    print('[onError][stack] $stack');
    return true; // handled
  };

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // Reuse the existing Firebase app to support hot restart on web
    Firebase.app();
  }

  // Debug: print current origin so you can whitelist it in Firebase Auth
  // ignore: avoid_print
  print('WEB_ORIGIN: ${Uri.base.origin}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinguaFlow',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
