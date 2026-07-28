import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'customer_profile_model.dart';
import 'customer_profile_repository.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState?.session ?? supabase.auth.currentSession;
});

final customerProfileProvider = FutureProvider<CustomerProfile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final repo = ref.watch(customerProfileRepositoryProvider);
  return repo.fetchOrCreate();
});
