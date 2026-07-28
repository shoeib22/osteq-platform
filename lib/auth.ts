import { createClient } from "@/lib/supabase/server";
import { prisma } from "@/lib/prisma";
import type { StaffRole } from "@prisma/client";

/**
 * middleware.ts only enforces authentication (is there a session at all) — it has no
 * concept of role, so every Server Action / Route Handler that performs a privileged
 * write (especially anything routed through the service-role Supabase client in
 * lib/supabase/admin.ts, which bypasses Row Level Security entirely) must check the
 * caller's actual staff membership itself; skipping that check means any authenticated
 * user — including a bare Supabase Auth signup with no matching `staff` row — could
 * invoke it.
 */
export async function requireStaffAccess(): Promise<{ id: string; role: StaffRole }> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Not authenticated.");
  }

  const staff = await prisma.staff.findUnique({ where: { id: user.id } });
  if (!staff) {
    throw new Error("Not authorized — staff access required.");
  }

  return { id: staff.id, role: staff.role };
}
