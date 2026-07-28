import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/price_tag.dart';
import 'catalog_provider.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key, this.categoryId, this.categoryName});

  final String? categoryId;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider(categoryId));

    return Scaffold(
      appBar: AppBar(title: Text(categoryName ?? 'Products')),
      body: productsAsync.when(
        data: (products) => RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider(categoryId).future),
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: product.variants.isNotEmpty
                    ? PriceTag(
                        priceInPaise: product.lowestPriceInPaise,
                        tier: product.variants.first.tier,
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'productDetail',
                  pathParameters: {'productId': product.id},
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load products: $error')),
      ),
    );
  }
}
