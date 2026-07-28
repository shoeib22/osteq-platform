import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    /*
     * Run on every page route except static assets and Next internals, so the Supabase
     * session cookie stays fresh across the whole app — not just /admin — while the
     * actual auth-gate redirect logic in updateSession only acts on /admin routes.
     *
     * Deliberately excludes /api/* too: every API route already does its own auth
     * (requireStaffAccess() for staff-triggered routes, requireOsteqCustomerAccess() for
     * customer-triggered ones) rather than relying on middleware's session-cookie refresh,
     * which only makes sense for browser page navigations anyway.
     */
    "/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|mp4)$).*)",
  ],
};
