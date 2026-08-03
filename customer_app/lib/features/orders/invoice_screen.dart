import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_model.dart';
import 'orders_provider.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: orderAsync.when(
        data: (order) => _InvoiceBody(order: order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load invoice: $error')),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Osteq', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const Text('AV & home-theater equipment for trade installers'),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice #${order.id.substring(0, 8).toUpperCase()}', style: textTheme.titleMedium),
                Text('Date: ${order.createdAt.toLocal().toString().substring(0, 10)}'),
                Text('Status: ${order.status}'),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.customerEmail != null) Text('Billed to: ${order.customerEmail}'),
                Text('Ship to: ${order.shippingAddress}', textAlign: TextAlign.right),
                if (order.trackingNumber != null) Text('Tracking: ${order.trackingNumber}'),
              ],
            ),
          ],
        ),
        const Divider(height: 32),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
          },
          border: TableBorder(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          children: [
            TableRow(
              children: [
                _cell('Item', bold: true),
                _cell('Qty', bold: true),
                _cell('Unit ₹', bold: true),
                _cell('Total ₹', bold: true),
              ],
            ),
            ...order.items.map(
              (item) => TableRow(
                children: [
                  _cell(item.productName ?? item.sku ?? item.variantId.substring(0, 8)),
                  _cell('${item.quantity}'),
                  _cell(item.unitPriceInRupees.toStringAsFixed(2)),
                  _cell(item.lineTotalInRupees.toStringAsFixed(2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Grand total: ₹${order.totalInRupees.toStringAsFixed(2)}',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'This is a system-generated invoice for the above order.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
