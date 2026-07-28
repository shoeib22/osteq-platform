import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import 'quotes_provider.dart';
import 'quotes_repository.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  final _messageController = TextEditingController();
  final _addressController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({required bool requestRevision}) async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(quotesRepositoryProvider)
          .addMessage(widget.quoteId, body, requestRevision: requestRevision);
      if (!mounted) return;
      _messageController.clear();
      ref.invalidate(quoteDetailProvider(widget.quoteId));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String decision) async {
    if (decision == 'ACCEPTED' && _addressController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a shipping address to accept.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(quotesRepositoryProvider).respond(
            widget.quoteId,
            decision,
            shippingAddress: decision == 'ACCEPTED' ? _addressController.text.trim() : null,
          );
      ref.invalidate(quotesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quoteDetailProvider(widget.quoteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quote')),
      body: quoteAsync.when(
        data: (quote) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Status: ${quote.status}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...quote.items.map((item) => ListTile(
                  title: Text(item.description ?? 'Variant ${item.productVariantId?.substring(0, 8)}'),
                  subtitle: Text('Qty: ${item.quantity}'),
                  trailing: Text(
                    item.quotedUnitPriceInPaise != null
                        ? '₹${(item.quotedUnitPriceInPaise! * item.quantity / 100).toStringAsFixed(2)}'
                        : 'Not yet priced',
                  ),
                )),
            if (quote.allItemsPriced) ...[
              const Divider(height: 32),
              Text(
                'Total: ₹${(quote.totalInPaise / 100).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const Divider(height: 32),
            Text('Messages', style: Theme.of(context).textTheme.titleMedium),
            ...quote.messages.map((m) => ListTile(
                  title: Text(m.body),
                  subtitle: Text(m.isFromStaff ? 'Osteq staff' : 'You'),
                )),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Add a message'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _sendMessage(requestRevision: false),
                  child: const Text('Send message'),
                ),
                if (quote.status == 'QUOTED')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _sendMessage(requestRevision: true),
                    child: const Text('Request revision'),
                  ),
              ],
            ),
            if (quote.status == 'QUOTED') ...[
              const Divider(height: 32),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Shipping address (to accept)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || !quote.allItemsPriced ? null : () => _respond('ACCEPTED'),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _respond('REJECTED'),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load quote: $error')),
      ),
    );
  }
}
