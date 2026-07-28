import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'trade_application_model.dart';

class TradeApplicationRepository {
  final Dio _dio;
  TradeApplicationRepository(this._dio);

  Future<TradeApplication> submit({
    required String businessName,
    required String businessType,
    required String phone,
    String? taxId,
  }) async {
    try {
      final res = await _dio.post('/api/osteq/trade-applications', data: {
        'businessName': businessName,
        'businessType': businessType,
        'phone': phone,
        if (taxId != null) 'taxId': taxId,
      });
      return TradeApplication.fromJson(res.data['application'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final tradeApplicationRepositoryProvider = Provider<TradeApplicationRepository>((ref) {
  return TradeApplicationRepository(ref.watch(apiClientProvider).dio);
});
