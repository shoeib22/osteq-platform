import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog_repository.dart';
import 'category_model.dart';
import 'product_model.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchCategories();
});

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, categoryId) async {
  return ref.watch(catalogRepositoryProvider).fetchProducts(categoryId: categoryId);
});

final productDetailProvider = FutureProvider.family<Product, String>((ref, productId) async {
  return ref.watch(catalogRepositoryProvider).fetchProduct(productId);
});

/// Products in the "projectors" category, for the Projector Calculator's model picker.
/// Resolves the category by slug rather than a hardcoded id, since ids are assigned at
/// seed time and differ per environment/database.
final projectorProductsProvider = FutureProvider<List<Product>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final matches = categories.where((c) => c.slug == 'projectors');
  if (matches.isEmpty) return [];
  return ref.watch(catalogRepositoryProvider).fetchProducts(categoryId: matches.first.id);
});
