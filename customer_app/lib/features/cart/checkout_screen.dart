import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../addresses/address_model.dart';
import '../addresses/address_repository.dart';
import '../addresses/address_form_screen.dart';
import '../orders/orders_repository.dart';
import 'cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _submitting = false;
  String? _error;
  String? _selectedAddressId;

  Future<void> _addNewAddress() async {
    final address = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (context) => const AddressFormScreen()),
    );
    if (address != null && mounted) {
      setState(() => _selectedAddressId = address.id);
    }
  }

  Future<void> _placeOrder(Address selected) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await ref.read(ordersRepositoryProvider).checkout(selected.summary);
      ref.invalidate(cartProvider);
      if (mounted) {
        context.pushReplacementNamed('orderConfirmation', pathParameters: {'orderId': order.id});
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: addressesAsync.when(
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
                Text('Deliver to', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No saved addresses yet — add one to continue.'),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: addresses
                          .map(
                            (address) => RadioListTile<String>(
                              value: address.id,
                              groupValue: _selectedAddressId,
                              onChanged: (value) => setState(() => _selectedAddressId = value),
                              title: Text(address.label),
                              subtitle: Text(address.summary),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _addNewAddress,
                  icon: const Icon(Icons.add),
                  label: const Text('Add new address'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting || selected == null ? null : () => _placeOrder(selected!),
                  child: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Place order'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Failed to load addresses: $error')),
        ),
      ),
    );
  }
}
