import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osteq_logo.dart';
import 'catalog_provider.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const OsteqLogo(),
      ),
      body: categoriesAsync.when(
        // Projectors aren't sold as a catalog item here — they only appear as
        // selectable models inside the Projector Calculator.
        data: (allCategories) {
          final categories = allCategories.where((c) => c.slug != 'projectors').toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(categoriesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.pushNamed(
                    'productList',
                    queryParameters: {'categoryId': category.id, 'categoryName': category.name},
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.category_outlined, color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load categories: $error')),
      ),
    );
  }
}
