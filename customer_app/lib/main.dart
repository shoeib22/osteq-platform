import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
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
