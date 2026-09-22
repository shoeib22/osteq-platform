import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import 'api_client.dart';
import 'push_service.dart';

/// Mirrors customerProfileProvider's pattern: registers this device's FCM token with the
/// backend whenever a Supabase session exists, and is a no-op otherwise (e.g. logged out).
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return;
  final dio = ref.watch(apiClientProvider).dio;
  await registerDeviceToken(dio);
});
