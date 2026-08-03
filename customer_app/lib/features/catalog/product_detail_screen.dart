import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../core/auth_guard.dart';
import '../../theme/app_colors.dart';
import '../../widgets/price_tag.dart';
import '../../widgets/product_image.dart';
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
  int _imageIndex = 0;

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
          final images = product.images;

          return ListView(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.isEmpty ? 1 : images.length,
                      onPageChanged: (i) => setState(() => _imageIndex = i),
                      itemBuilder: (context, i) => ProductImage(
                        imagePath: images.isEmpty ? null : images[i],
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _imageIndex
                                    ? AppColors.gold
                                    : AppColors.textDisabled,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                    if (product.description != null) ...[
                      const SizedBox(height: 8),
                      Text(product.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 20),
                    if (product.variants.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ProductVariant>(
                            value: variant,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceRaised,
                            items: product.variants
                                .map((v) => DropdownMenuItem(value: v, child: Text(v.attributesLabel)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedVariant = v),
                          ),
                        ),
                      ),
                    if (variant != null) ...[
                      const SizedBox(height: 16),
                      PriceTag(priceInRupees: variant.priceInRupees, tier: variant.tier),
                      const SizedBox(height: 4),
                      Text(
                        variant.stockQuantity > 0 ? '${variant.stockQuantity} in stock' : 'Out of stock',
                        style: TextStyle(
                          color: variant.stockQuantity > 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _QuantityStepper(
                          quantity: _quantity,
                          onDecrement: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          onIncrement: () => setState(() => _quantity++),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: variant == null || _adding ? null : _addToCart,
                            child: _adding
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Add to cart'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load product: $error')),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, this.onDecrement, required this.onIncrement});

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: onDecrement),
          SizedBox(
            width: 24,
            child: Text('$quantity', textAlign: TextAlign.center),
          ),
          IconButton(icon: const Icon(Icons.add, size: 18), onPressed: onIncrement),
        ],
      ),
    );
  }
}
