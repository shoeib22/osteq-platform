import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a Stream (Supabase's auth-state stream) into a Listenable GoRouter can watch
/// via refreshListenable — without this, GoRouter only re-evaluates `redirect` on
/// navigation events, so a sign-in/sign-out happening without a route change (e.g. right
/// after submitting the login form) would never actually kick the router into rerouting.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
