import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'order_model.dart';

class OrdersRepository {
  final Dio _dio;
  OrdersRepository(this._dio);

  Future<Order> checkout(String shippingAddress) async {
    try {
      final res = await _dio.post('/api/osteq/checkout', data: {'shippingAddress': shippingAddress});
      return Order.fromJson(res.data['order'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Order>> fetchAll() async {
    try {
      final res = await _dio.get('/api/osteq/orders');
      return (res.data['orders'] as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Order> fetchOne(String orderId) async {
    try {
      final res = await _dio.get('/api/osteq/orders/$orderId');
      return Order.fromJson(res.data['order'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<String> fetchInvoiceDownloadUrl(String orderId) async {
    try {
      final res = await _dio.get('/api/osteq/orders/$orderId/invoice-download');
      return res.data['url'] as String;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider).dio);
});
