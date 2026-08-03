import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;

/// The backend stores relative storage paths (e.g. "productId/uuid.png"), never a full
/// URL — a URL baked in server-side would only ever be correct for whichever consumer
/// (this app, over its own ephemeral tunnel, vs. the admin panel, over localhost) happened
/// to match at upload time. Each consumer resolves paths against its own known base URL
/// instead; this is this app's side of that split.
String resolveStoragePublicUrl(String bucket, String path) {
  return '$supabaseUrl/storage/v1/object/public/$bucket/$path';
}
