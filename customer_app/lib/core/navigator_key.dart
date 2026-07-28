import 'package:flutter/material.dart';

/// A global navigator key lets code with no BuildContext (like the dio error
/// interceptor) trigger navigation — e.g. redirecting to login on a 401 — without
/// needing to plumb a context through every repository call.
final rootNavigatorKey = GlobalKey<NavigatorState>();
