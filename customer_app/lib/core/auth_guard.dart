import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';

bool ensureSignedIn(BuildContext context, WidgetRef ref) {
  final session = ref.read(currentSessionProvider);
  if (session == null) {
    context.pushNamed('login');
    return false;
  }
  return true;
}
