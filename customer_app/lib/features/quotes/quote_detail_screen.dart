import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../addresses/address_model.dart';
import '../addresses/address_repository.dart';
import '../addresses/address_form_screen.dart';
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
  bool _busy = false;
  String? _error;
  String? _selectedAddressId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _addNewAddress() async {
    final address = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (context) => const AddressFormScreen()),
    );
    if (address != null && mounted) {
      setState(() => _selectedAddressId = address.id);
    }
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

  Future<void> _respond(String decision, {Address? shippingTo}) async {
    if (decision == 'ACCEPTED' && shippingTo == null) {
      setState(() => _error = 'Choose a shipping address to accept.');
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
            shippingAddress: decision == 'ACCEPTED' ? shippingTo!.summary : null,
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
                    item.quotedUnitPriceInRupees != null
                        ? '₹${(item.quotedUnitPriceInRupees! * item.quantity).toStringAsFixed(2)}'
                        : 'Not yet priced',
                  ),
                )),
            if (quote.allItemsPriced) ...[
              const Divider(height: 32),
              Text(
                'Total: ₹${quote.totalInRupees.toStringAsFixed(2)}',
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
              Text('Deliver to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final addressesAsync = ref.watch(addressListProvider);
                return addressesAsync.when(
                  data: (addresses) {
                    if (_selectedAddressId == null && addresses.isNotEmpty) {
                      final defaultAddress = addresses.firstWhere(
                        (a) => a.isDefault,
                        orElse: () => addresses.first,
                      );
                      _selectedAddressId = defaultAddress.id;
                    }
                    Address? selected;
                    for (final a in addresses) {
                      if (a.id == _selectedAddressId) {
                        selected = a;
                        break;
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (addresses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No saved addresses yet — add one to accept.'),
                          )
                        else
                          ...addresses.map(
                            (address) => RadioListTile<String>(
                              value: address.id,
                              groupValue: _selectedAddressId,
                              onChanged: (value) => setState(() => _selectedAddressId = value),
                              title: Text(address.label),
                              subtitle: Text(address.summary),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _addNewAddress,
                          icon: const Icon(Icons.add),
                          label: const Text('Add new address'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy || !quote.allItemsPriced || selected == null
                                    ? null
                                    : () => _respond('ACCEPTED', shippingTo: selected),
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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Failed to load addresses: $error'),
                );
              }),
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
