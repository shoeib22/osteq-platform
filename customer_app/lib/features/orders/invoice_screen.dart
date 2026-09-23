import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_exception.dart';
import 'order_model.dart';
import 'orders_provider.dart';
import 'orders_repository.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: orderAsync.when(
        data: (order) =>
            order.hasInvoicePdf ? _InvoicePdfDownload(orderId: orderId) : _InvoiceBody(order: order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load invoice: $error')),
      ),
    );
  }
}

class _InvoicePdfDownload extends ConsumerStatefulWidget {
  const _InvoicePdfDownload({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_InvoicePdfDownload> createState() => _InvoicePdfDownloadState();
}

class _InvoicePdfDownloadState extends ConsumerState<_InvoicePdfDownload> {
  bool _loading = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref.read(ordersRepositoryProvider).fetchInvoiceDownloadUrl(widget.orderId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 48),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _download,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: const Text('Download invoice PDF'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
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
