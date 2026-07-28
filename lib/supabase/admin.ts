import { createClient } from "@supabase/supabase-js";
import { supabaseUrl, supabaseServiceRoleKey } from "./env";

/**
 * Service-role Supabase client — bypasses Row Level Security. Server-only (imports of
 * this file must never reach a Client Component).
 */
export function createAdminClient() {
  return createClient(supabaseUrl(), supabaseServiceRoleKey());
}
