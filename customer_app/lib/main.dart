import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/push_service.dart';
import 'theme/app_theme.dart';

const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  // Skipped when unconfigured (fresh checkout, no Firebase project set up yet) — the rest
  // of the app works fine without it, push just stays inert until these are provided.
  if (firebaseApiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
      ),
    );
    setupNotificationTapHandling();
  }
  runApp(const ProviderScope(child: OsteqApp()));
}

class OsteqApp extends StatelessWidget {
  const OsteqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Osteq',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
