import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'cart_item_model.dart';

class CartRepository {
  final Dio _dio;
  CartRepository(this._dio);

  Future<List<CartItem>> fetch() async {
    try {
      final res = await _dio.get('/api/osteq/cart');
      return (res.data['items'] as List)
          .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> addItem(String variantId, int quantity) async {
    try {
      await _dio.post('/api/osteq/cart', data: {'variantId': variantId, 'quantity': quantity});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    try {
      await _dio.patch('/api/osteq/cart/items/$itemId', data: {'quantity': quantity});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await _dio.delete('/api/osteq/cart/items/$itemId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider).dio);
});
