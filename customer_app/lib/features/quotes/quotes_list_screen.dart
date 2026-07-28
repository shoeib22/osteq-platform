import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_guard.dart';
import 'quotes_provider.dart';

class QuotesListScreen extends ConsumerWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quotes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!ensureSignedIn(context, ref)) return;
          context.pushNamed('newQuote');
        },
        child: const Icon(Icons.add),
      ),
      body: quotesAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return const Center(child: Text('No quotes yet'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(quotesProvider.future),
            child: ListView.builder(
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return ListTile(
                  title: Text('Quote #${quote.id.substring(0, 8)}'),
                  subtitle: Text(quote.status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('quoteDetail', pathParameters: {'id': quote.id}),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load quotes: $error')),
      ),
    );
  }
}
