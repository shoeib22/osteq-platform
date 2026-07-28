import { createClient } from "@supabase/supabase-js";
import type { NextRequest } from "next/server";
import { supabaseUrl, supabaseAnonKey } from "@/lib/supabase/env";

/**
 * Osteq customer equivalent of lib/auth-mobile.ts's requireTechnicianAccess() — verifies
 * the bearer token against Supabase's auth server and returns the raw auth user, without
 * requiring an OsteqCustomerProfile row to already exist (unlike requireTechnicianAccess,
 * where the Technician row is provisioned by staff ahead of time). Osteq customers create
 * their own profile row on first call to POST /api/osteq/customers/me, so this helper can't
 * assume the row is there yet — callers that need the profile query it themselves.
 */
export async function requireOsteqCustomerAccess(
  request: NextRequest,
): Promise<{ customerId: string; email: string }> {
  const authHeader = request.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length) : "";
  if (!token) {
    throw new Error("Missing bearer token.");
  }

  const supabase = createClient(supabaseUrl(), supabaseAnonKey());
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);
  if (error || !user || !user.email) {
    throw new Error("Invalid or expired token.");
  }

  return { customerId: user.id, email: user.email };
}
