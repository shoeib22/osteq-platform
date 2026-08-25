import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

const CORS_METHODS = "GET, POST, PATCH, PUT, DELETE, OPTIONS";
const CORS_HEADERS = "Content-Type, Authorization";

function withCors(response: NextResponse) {
  // Wildcard origin is safe here: /api/osteq/* authenticates via a Bearer token
  // (requireOsteqCustomerAccess / requireStaffAccess), never cookies, so this doesn't widen
  // any credentialed access — it just lets a browser-hosted client (the Flutter customer
  // app's web build) read the response instead of the request being blocked by CORS.
  response.headers.set("Access-Control-Allow-Origin", "*");
  response.headers.set("Access-Control-Allow-Methods", CORS_METHODS);
  response.headers.set("Access-Control-Allow-Headers", CORS_HEADERS);
  return response;
}

export async function middleware(request: NextRequest) {
  if (request.nextUrl.pathname.startsWith("/api/osteq")) {
    if (request.method === "OPTIONS") {
      return withCors(new NextResponse(null, { status: 204 }));
    }
    return withCors(NextResponse.next());
  }

  return updateSession(request);
}

export const config = {
  matcher: [
    /*
     * Run on every page route except static assets and Next internals, so the Supabase
     * session cookie stays fresh across the whole app — not just /admin — while the
     * actual auth-gate redirect logic in updateSession only acts on /admin routes.
     *
     * Also runs on /api/osteq/* (see the CORS branch above) so a browser-hosted client on a
     * different origin can read the response. Other /api/* namespaces stay excluded: they
     * have no cross-origin browser caller and don't need CORS headers or updateSession's
     * cookie refresh, which only makes sense for browser page navigations anyway.
     */
    "/((?!api/(?!osteq)|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|mp4)$).*)",
  ],
};
