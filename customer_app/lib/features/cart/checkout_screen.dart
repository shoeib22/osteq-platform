import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../orders/orders_repository.dart';
import 'cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged() => setState(() {});

  Future<void> _placeOrder() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(ordersRepositoryProvider).checkout(_addressController.text.trim());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Shipping address'),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting || _addressController.text.trim().isEmpty ? null : _placeOrder,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }
}
