import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'customer_profile_model.dart';

class CustomerProfileRepository {
  final Dio _dio;
  CustomerProfileRepository(this._dio);

  Future<CustomerProfile> fetchOrCreate() async {
    try {
      final res = await _dio.get('/api/osteq/customers/me');
      return CustomerProfile.fromJson(res.data['profile'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return createOrUpdate();
      }
      throwApiException(e);
    }
  }

  Future<CustomerProfile> createOrUpdate({
    String? businessName,
    String? businessType,
    String? phone,
  }) async {
    try {
      final res = await _dio.post('/api/osteq/customers/me', data: {
        if (businessName != null) 'businessName': businessName,
        if (businessType != null) 'businessType': businessType,
        if (phone != null) 'phone': phone,
      });
      return CustomerProfile.fromJson(res.data['profile'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((ref) {
  return CustomerProfileRepository(ref.watch(apiClientProvider).dio);
});
