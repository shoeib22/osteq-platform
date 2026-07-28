import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api_exception.dart';
import 'navigator_key.dart';
import 'supabase_client.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class OsteqApiClient {
  final Dio dio;

  OsteqApiClient() : dio = Dio(BaseOptions(baseUrl: apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = supabase.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final data = error.response?.data;
          final message = data is Map && data['error'] is String
              ? data['error'] as String
              : 'Something went wrong. Please try again.';
          if (error.response?.statusCode == 401) {
            final context = rootNavigatorKey.currentContext;
            if (context != null && context.mounted) {
              GoRouter.of(context).pushNamed('login');
            }
          }
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: ApiException(error.response?.statusCode ?? 0, message),
            ),
          );
        },
      ),
    );
  }
}

final apiClientProvider = Provider<OsteqApiClient>((ref) => OsteqApiClient());

// Every repository's DioException catch block calls this instead of rethrowing the raw
// DioException, so widgets only ever need to catch ApiException — the onError interceptor
// above always attaches one, but this satisfies the type system without an unsafe cast.
Never throwApiException(DioException e) {
  final err = e.error;
  if (err is ApiException) throw err;
  throw ApiException(0, 'Network error. Please check your connection.');
}
