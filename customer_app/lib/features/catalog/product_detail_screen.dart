import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../core/auth_guard.dart';
import '../../widgets/price_tag.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_repository.dart';
import 'catalog_provider.dart';
import 'product_model.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  bool _adding = false;

  Future<void> _addToCart() async {
    if (!ensureSignedIn(context, ref)) return;
    final variant = _selectedVariant;
    if (variant == null) return;

    setState(() => _adding = true);
    try {
      await ref.read(cartRepositoryProvider).addItem(variant.id, _quantity);
      ref.invalidate(cartProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: productAsync.when(
        data: (product) {
          _selectedVariant ??= product.variants.isNotEmpty ? product.variants.first : null;
          final variant = _selectedVariant;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                if (product.description != null) ...[
                  const SizedBox(height: 8),
                  Text(product.description!),
                ],
                const SizedBox(height: 16),
                if (product.variants.length > 1)
                  DropdownButton<ProductVariant>(
                    value: variant,
                    isExpanded: true,
                    items: product.variants
                        .map((v) => DropdownMenuItem(value: v, child: Text(v.attributesLabel)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVariant = v),
                  ),
                if (variant != null) ...[
                  const SizedBox(height: 12),
                  PriceTag(priceInPaise: variant.priceInPaise, tier: variant.tier),
                  const SizedBox(height: 4),
                  Text('${variant.stockQuantity} in stock'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text('$_quantity'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: variant == null || _adding ? null : _addToCart,
                  child: _adding
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add to cart'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load product: $error')),
      ),
    );
  }
}
