import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
