import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'quote_model.dart';

class QuotesRepository {
  final Dio _dio;
  QuotesRepository(this._dio);

  Future<Quote> submit(List<Map<String, dynamic>> items) async {
    try {
      final res = await _dio.post('/api/osteq/quotes', data: {'items': items});
      return Quote.fromJson(res.data['quote'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Quote>> fetchAll() async {
    try {
      final res = await _dio.get('/api/osteq/quotes');
      return (res.data['quotes'] as List)
          .map((q) => Quote.fromJson(q as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Quote> fetchOne(String quoteId) async {
    try {
      final res = await _dio.get('/api/osteq/quotes/$quoteId');
      return Quote.fromJson(res.data['quote'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> addMessage(String quoteId, String body, {bool requestRevision = false}) async {
    try {
      await _dio.post('/api/osteq/quotes/$quoteId/messages', data: {
        'body': body,
        if (requestRevision) 'requestRevision': true,
      });
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> respond(String quoteId, String decision, {String? shippingAddress}) async {
    try {
      await _dio.post('/api/osteq/quotes/$quoteId/respond', data: {
        'decision': decision,
        if (shippingAddress != null) 'shippingAddress': shippingAddress,
      });
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(apiClientProvider).dio);
});
