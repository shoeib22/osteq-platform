import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'category_model.dart';
import 'product_model.dart';

class CatalogRepository {
  final Dio _dio;
  CatalogRepository(this._dio);

  Future<List<Category>> fetchCategories() async {
    try {
      final res = await _dio.get('/api/osteq/categories');
      return (res.data['categories'] as List)
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Product>> fetchProducts({String? categoryId}) async {
    try {
      final res = await _dio.get(
        '/api/osteq/products',
        queryParameters: categoryId != null ? {'categoryId': categoryId} : null,
      );
      return (res.data['products'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Product> fetchProduct(String productId) async {
    try {
      final res = await _dio.get('/api/osteq/products/$productId');
      return Product.fromJson(res.data['product'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider).dio);
});
