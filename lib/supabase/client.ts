import { createBrowserClient } from "@supabase/ssr";
import { supabaseUrl, supabaseAnonKey } from "./env";

/**
 * Supabase client for Client Components / the browser. Uses the public anon key —
 * safe to expose, since it's subject to Row Level Security.
 */
export function createClient() {
  return createBrowserClient(supabaseUrl(), supabaseAnonKey());
}
