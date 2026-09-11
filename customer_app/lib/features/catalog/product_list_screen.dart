import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/price_tag.dart';
import '../../widgets/product_image.dart';
import 'catalog_provider.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.categorySlug,
  });

  final String? categoryId;
  final String? categoryName;
  final String? categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider(categoryId));
    // Whoever's browsing screens is the person most likely to need the throw-distance /
    // screen-size math right now — surface the calculator right where that decision happens,
    // not just as a generic banner back on the catalog home screen.
    final showCalculatorBanner = categorySlug == 'projection-screens';

    return Scaffold(
      appBar: AppBar(title: Text(categoryName ?? 'Products')),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text('No products in this category yet.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(productsProvider(categoryId).future),
            child: CustomScrollView(
              slivers: [
                if (showCalculatorBanner)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CalculatorContextBanner(),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: products.length,
                      (context, index) {
                        final product = products[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.pushNamed(
                            'productDetail',
                            pathParameters: {'productId': product.id},
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ProductImage(
                                    imagePath: product.images.isNotEmpty
                                        ? product.images.first
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 6),
                                      if (product.variants.isNotEmpty)
                                        PriceTag(
                                          priceInRupees:
                                              product.lowestPriceInRupees,
                                          tier: product.variants.first.tier,
                                        )
                                      else
                                        Text(
                                          'Unavailable',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Failed to load products: $error')),
      ),
    );
  }
}

/// Contextual nudge shown only on the Projection Screens category — someone already
/// choosing a screen is exactly who benefits from sizing throw distance/screen size first.
class _CalculatorContextBanner extends StatelessWidget {
  const _CalculatorContextBanner();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.pushNamed('projectorCalculator'),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Not sure what size fits your room? Size it with the Projector Calculator.",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.gold),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold, size: 18),
          ],
        ),
      ),
    );
  }
}
