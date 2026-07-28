import 'package:flutter/material.dart';

class QuotesListScreen extends StatelessWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotes')),
      body: const Center(child: Text('Quotes load here')),
    );
  }
}
