import Link from "next/link";
import { redirect } from "next/navigation";
import { requireStaffAccess } from "@/lib/auth";
import { logoutAction } from "./actions";

export default async function AdminDashboardLayout({ children }: { children: React.ReactNode }) {
  try {
    await requireStaffAccess();
  } catch (err) {
    // Log why, not just that — a bare catch here previously made "valid session, no staff
    // row" indistinguishable from "no session at all" from the outside: both just bounced
    // to /admin/login with zero trace, which looked identical to an actual redirect loop
    // when the session WAS valid (middleware kept sending it back to /admin each time).
    console.error("[admin layout] requireStaffAccess failed:", err);
    redirect("/admin/login");
  }

  return (
    <div className="min-h-screen">
      <nav className="flex items-center gap-6 border-b px-6 py-4">
        <Link href="/admin/trade-applications">Trade Applications</Link>
        <Link href="/admin/catalog">Catalog</Link>
        <Link href="/admin/quotes">Quotes</Link>
        <Link href="/admin/orders">Orders</Link>
        <form action={logoutAction} className="ml-auto">
          <button type="submit" className="text-sm underline">
            Log out
          </button>
        </form>
      </nav>
      <main className="p-6">{children}</main>
    </div>
  );
}
