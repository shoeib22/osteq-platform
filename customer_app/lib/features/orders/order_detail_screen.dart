import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'orders_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'View invoice',
            onPressed: () => context.pushNamed('orderInvoice', pathParameters: {'id': orderId}),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Status: ${order.status}'),
            Text('Shipping to: ${order.shippingAddress}'),
            if (order.trackingNumber != null) Text('Tracking: ${order.trackingNumber}'),
            const Divider(height: 32),
            ...order.items.map((item) => ListTile(
                  title: Text(item.productName ?? item.sku ?? 'Variant ${item.variantId.substring(0, 8)}'),
                  subtitle: Text('Qty: ${item.quantity} × ₹${item.unitPriceInRupees.toStringAsFixed(2)}'),
                  trailing: Text('₹${item.lineTotalInRupees.toStringAsFixed(2)}'),
                )),
            const Divider(height: 32),
            Text(
              'Total: ₹${order.totalInRupees.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load order: $error')),
      ),
    );
  }
}
