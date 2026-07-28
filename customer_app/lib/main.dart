import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OsteqApp());
}

class OsteqApp extends StatelessWidget {
  const OsteqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osteq',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('Osteq'))),
    );
  }
}
