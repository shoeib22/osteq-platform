import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'navigator_key.dart';

bool _tapHandlersRegistered = false;

/// Registers handlers that react to a push notification being tapped, both while the app
/// is backgrounded (onMessageOpenedApp) and the cold-start case where the tap launched the
/// app (getInitialMessage). Called once from main() — navigation doesn't require an
/// authenticated session to be wired up, only the destination screen's own API calls do.
void setupNotificationTapHandling() {
  if (_tapHandlersRegistered) return;
  _tapHandlersRegistered = true;

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handleMessageTap(message);
  });
}

void _handleMessageTap(RemoteMessage message) {
  final orderId = message.data['orderId'];
  if (orderId is! String || orderId.isEmpty) return;
  final context = rootNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    GoRouter.of(context).pushNamed('orderDetail', pathParameters: {'id': orderId});
  }
}

bool _refreshListenerRegistered = false;

/// Requests notification permission, registers the current FCM token with the backend,
/// and (once) subscribes to token-refresh so a renewed token gets re-registered too.
/// A no-op if Firebase was never initialized (main.dart skips init when the
/// --dart-define Firebase values aren't configured yet).
Future<void> registerDeviceToken(Dio dio) async {
  if (Firebase.apps.isEmpty) return;

  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await _postToken(dio, token);
  }

  if (!_refreshListenerRegistered) {
    _refreshListenerRegistered = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) => _postToken(dio, newToken));
  }
}

Future<void> _postToken(Dio dio, String token) async {
  try {
    await dio.post('/api/osteq/customers/device-token', data: {'fcmToken': token});
  } on DioException {
    // Best-effort — a failed device-token registration shouldn't block app usage, only
    // means this device won't receive push until the next successful registration
    // attempt (e.g. next login or token refresh).
  }
}
