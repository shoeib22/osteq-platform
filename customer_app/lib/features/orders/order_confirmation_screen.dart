import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'orders_provider.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order placed')),
      body: orderAsync.when(
        data: (order) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text('Order #${order.id.substring(0, 8)} confirmed'),
              const SizedBox(height: 4),
              Text('Total: ₹${order.totalInRupees.toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.goNamed('catalog'),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load order: $error')),
      ),
    );
  }
}
