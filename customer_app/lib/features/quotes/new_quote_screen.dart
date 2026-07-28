import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../catalog/catalog_provider.dart';
import '../catalog/product_model.dart';
import 'quotes_provider.dart';
import 'quotes_repository.dart';

class _DraftLine {
  final ProductVariant? variant;
  final String? productName;
  final String? description;
  int quantity;

  _DraftLine({this.variant, this.productName, this.description, this.quantity = 1});
}

class NewQuoteScreen extends ConsumerStatefulWidget {
  const NewQuoteScreen({super.key});

  @override
  ConsumerState<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends ConsumerState<NewQuoteScreen> {
  final List<_DraftLine> _lines = [];
  final _customDescriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _customDescriptionController.dispose();
    super.dispose();
  }

  void _addCustomLine() {
    final description = _customDescriptionController.text.trim();
    if (description.isEmpty) return;
    setState(() {
      _lines.add(_DraftLine(description: description));
      _customDescriptionController.clear();
    });
  }

  Future<void> _pickCatalogItem() async {
    final products = await ref.read(productsProvider(null).future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<Product>(
      context: context,
      builder: (context) => ListView(
        children: products
            .map((p) => ListTile(title: Text(p.name), onTap: () => Navigator.pop(context, p)))
            .toList(),
      ),
    );
    if (selected == null || selected.variants.isEmpty) return;
    if (mounted) {
      setState(() {
        _lines.add(_DraftLine(variant: selected.variants.first, productName: selected.name));
      });
    }
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final items = _lines
          .map((line) => {
                if (line.variant != null) 'productVariantId': line.variant!.id,
                if (line.description != null) 'description': line.description,
                'quantity': line.quantity,
              })
          .toList();
      await ref.read(quotesRepositoryProvider).submit(items);
      ref.invalidate(quotesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New quote')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: _lines
                    .map((line) => ListTile(
                          title: Text(line.productName ?? line.description ?? ''),
                          subtitle: Text('Qty: ${line.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _lines.remove(line)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickCatalogItem,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Add catalog item'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customDescriptionController,
                    decoration: const InputDecoration(labelText: 'Custom item description'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addCustomLine),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _lines.isEmpty || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit quote'),
            ),
          ],
        ),
      ),
    );
  }
}
