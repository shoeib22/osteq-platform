import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'address_model.dart';

class AddressRepository {
  final Dio _dio;
  AddressRepository(this._dio);

  Future<List<Address>> list() async {
    try {
      final res = await _dio.get('/api/osteq/addresses');
      final addresses = res.data['addresses'] as List;
      return addresses.map((a) => Address.fromJson(a as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Address> create({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String postalCode,
    String? country,
    String? phone,
    bool isDefault = false,
  }) async {
    try {
      final res = await _dio.post('/api/osteq/addresses', data: {
        'label': label,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        if (country != null) 'country': country,
        if (phone != null) 'phone': phone,
        'isDefault': isDefault,
      });
      return Address.fromJson(res.data['address'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Address> update(
    String id, {
    String? label,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phone,
    bool? isDefault,
  }) async {
    try {
      final res = await _dio.patch('/api/osteq/addresses/$id', data: {
        if (label != null) 'label': label,
        if (line1 != null) 'line1': line1,
        if (line2 != null) 'line2': line2,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
        if (phone != null) 'phone': phone,
        if (isDefault != null) 'isDefault': isDefault,
      });
      return Address.fromJson(res.data['address'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/api/osteq/addresses/$id');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(apiClientProvider).dio);
});

final addressListProvider = FutureProvider.autoDispose<List<Address>>((ref) {
  return ref.watch(addressRepositoryProvider).list();
});
