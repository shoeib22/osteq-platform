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
