# Osteq Admin Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Osteq admin panel per `docs/superpowers/specs/2026-07-29-admin-panel-design.md` — a Next.js web dashboard for staff to review trade applications, manage the catalog, price/respond to quotes, and manage orders.

**Architecture:** New `app/admin/*` routes in this repo. Server Components read Prisma directly; mutations go through the existing, already-reviewed `/api/osteq/*` routes via a shared `fetch`-based helper that forwards the staff session cookie — reusing every race-condition guard already built rather than duplicating them. Three small backend gaps (category edit, variant edit, staff-facing order list) are added first since later tasks depend on them.

**Tech Stack:** Next.js 14 App Router (Server Components + Server Actions), Prisma, React 18.3 (`useState` + `useTransition` from `react` for form state/pending — `useFormState`/`useFormStatus` from `react-dom` and `useActionState` from `react` are NOT available: verified empirically that the installed `react-dom@18.3.1` does not export the first two, and `useActionState` is React-19-only), Tailwind (plain utility classes only — no custom theme; visual polish is explicitly deferred).

## Global Constraints

- No test runner exists in this repo — verification is manual (`npx tsc --noEmit`, `npm run build`, and a browser walkthrough in the final task).
- **Do not use `useFormState`/`useFormStatus` (from `react-dom`) or `useActionState` (from `react`) anywhere in this plan.** A prior task in this same plan verified directly (`node -e "require('react-dom').useFormState"` → `undefined`) that the installed `react-dom@18.3.1` does not export these — `tsc --noEmit` will falsely report no error, because Next.js's ambient `react-dom/experimental` type augmentation lies about what's exported at runtime, but the app throws `TypeError` at render. Every form instead: (1) is a `"use client"` component owning its own `const [error, setError] = useState<string | undefined>()` and `const [isPending, startTransition] = useTransition()`; (2) has a plain `onSubmit={(e) => { e.preventDefault(); const formData = new FormData(e.currentTarget); startTransition(async () => { const result = await someAction(formData); setError(result?.error); }); }}` handler; (3) calls the imported Server Action directly as a plain async function (Server Actions are callable async functions from client code regardless of React version — only the special hooks are unavailable); (4) renders `<SubmitButton pending={isPending}>Label</SubmitButton>` (Task 3's `SubmitButton` takes `pending` as an explicit prop, not via `useFormStatus()` context) and `{error && <span className="text-xs text-red-600">{error}</span>}`. Every Server Action's signature drops the unused `_prevState` parameter `useFormState` used to require: `async function someAction(formData: FormData): Promise<{ error?: string } | null>`.
- Server Actions never talk to Prisma directly for mutations — every mutation goes through `adminApiFetch` (Task 3) calling the existing `/api/osteq/*` route, so race-condition guards already built and reviewed in the backend are never duplicated.
- Match existing code style: no comments explaining *what* code does, only non-obvious *why*.
- Money is always `Int`/`*InPaise` — the admin UI shows raw paise values (no currency formatting) matching the rest of this repo's current state; formatting is part of the deferred visual-polish pass, not this plan.
- Run every command from `C:\Users\Shoeii\osteq-platform` (this repo's root).

---

### Task 1: Backend — category and variant edit routes

**Files:**
- Create: `app/api/osteq/categories/[id]/route.ts`
- Create: `app/api/osteq/products/[id]/variants/[variantId]/route.ts`

**Interfaces:**
- Consumes: `requireStaffAccess` (`@/lib/auth`), `prisma`.
- Produces: `PATCH /api/osteq/categories/[id]` → `{ category: OsteqCategory }`. `PATCH /api/osteq/products/[id]/variants/[variantId]` → `{ variant: OsteqProductVariant }`. Both consumed by Task 5/7's Server Actions.

- [ ] **Step 1: Write the category edit route**

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqCategory.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: "Category not found." }, { status: 404 });
  }

  const body = await request.json();
  const name = typeof body.name === "string" && body.name.trim() ? body.name.trim() : existing.name;
  const slug = typeof body.slug === "string" && body.slug.trim() ? body.slug.trim() : existing.slug;
  const parentCategoryId =
    body.parentCategoryId === null
      ? null
      : typeof body.parentCategoryId === "string"
        ? body.parentCategoryId
        : existing.parentCategoryId;

  const category = await prisma.osteqCategory.update({
    where: { id: params.id },
    data: { name, slug, parentCategoryId },
  });
  return NextResponse.json({ category });
}
```

- [ ] **Step 2: Write the variant edit route**

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string; variantId: string } },
) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqProductVariant.findUnique({ where: { id: params.variantId } });
  if (!existing || existing.productId !== params.id) {
    return NextResponse.json({ error: "Variant not found." }, { status: 404 });
  }

  const body = await request.json();
  const sku = typeof body.sku === "string" && body.sku.trim() ? body.sku.trim() : existing.sku;
  const attributes = body.attributes !== undefined ? body.attributes : existing.attributes;
  const retailPriceInPaise = Number.isFinite(Number(body.retailPriceInPaise))
    ? Number(body.retailPriceInPaise)
    : existing.retailPriceInPaise;
  const tradePriceInPaise = Number.isFinite(Number(body.tradePriceInPaise))
    ? Number(body.tradePriceInPaise)
    : existing.tradePriceInPaise;
  const stockQuantity = Number.isFinite(Number(body.stockQuantity))
    ? Number(body.stockQuantity)
    : existing.stockQuantity;
  const isActive = typeof body.isActive === "boolean" ? body.isActive : existing.isActive;

  const variant = await prisma.osteqProductVariant.update({
    where: { id: params.variantId },
    data: { sku, attributes, retailPriceInPaise, tradePriceInPaise, stockQuantity, isActive },
  });
  return NextResponse.json({ variant });
}
```

- [ ] **Step 3: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "categories/\[id\]\|variants/\[variantId\]" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 4: Commit**

```bash
git add "app/api/osteq/categories/[id]" "app/api/osteq/products/[id]/variants/[variantId]"
git commit -m "Add category and variant edit routes"
```

---

### Task 2: Backend — staff-facing order list and detail

**Files:**
- Modify: `app/api/osteq/orders/route.ts`
- Modify: `app/api/osteq/orders/[id]/route.ts`

**Interfaces:**
- Consumes: `requireOsteqCustomerAccess` (`@/lib/osteq/auth`), `requireStaffAccess` (`@/lib/auth`), `prisma`.
- Produces: `GET /api/osteq/orders` and `GET /api/osteq/orders/[id]` now return every order when called by staff, and only the caller's own orders when called by a customer — same dual-auth pattern as `GET /api/osteq/quotes`. Consumed by Task 10/11.

- [ ] **Step 1: Add the staff bypass to the order list route**

Replace the full contents of `app/api/osteq/orders/route.ts` with:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";

export async function GET(request: NextRequest) {
  let customerId: string | null = null;
  let isStaff = false;
  try {
    await requireStaffAccess();
    isStaff = true;
  } catch {
    try {
      ({ customerId } = await requireOsteqCustomerAccess(request));
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const orders = await prisma.osteqOrder.findMany({
    where: isStaff ? {} : { customerId: customerId! },
    include: { items: true },
    orderBy: { createdAt: "desc" },
  });

  return NextResponse.json({ orders });
}
```

- [ ] **Step 2: Add the staff bypass to the order detail route**

Replace the full contents of `app/api/osteq/orders/[id]/route.ts` with:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string | null = null;
  try {
    await requireStaffAccess();
  } catch {
    try {
      ({ customerId } = await requireOsteqCustomerAccess(request));
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { items: true },
  });
  if (!order || (customerId && order.customerId !== customerId)) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  return NextResponse.json({ order });
}
```

- [ ] **Step 3: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "osteq/orders" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 4: Commit**

```bash
git add app/api/osteq/orders
git commit -m "Add staff bypass to order list and detail routes"
```

---

### Task 3: Admin shell — API helper, submit button, login, dashboard layout

**Files:**
- Create: `lib/admin/api-fetch.ts`
- Create: `app/admin/(dashboard)/SubmitButton.tsx`
- Create: `app/admin/login/actions.ts`
- Create: `app/admin/login/page.tsx`
- Create: `app/admin/(dashboard)/actions.ts`
- Create: `app/admin/(dashboard)/layout.tsx`
- Create: `app/admin/(dashboard)/page.tsx`

**Interfaces:**
- Consumes: `requireStaffAccess` (`@/lib/auth`), `createClient` (`@/lib/supabase/server`).
- Produces: `export async function adminApiFetch<T>(path: string, options?: { method?: string; body?: unknown }): Promise<{ data?: T; error?: string }>` — consumed by every `actions.ts` in Tasks 4-11. `export function SubmitButton({ pending: boolean, children, className? }): JSX.Element` — a plain presentational client component (its `pending` state is passed in as a prop by the parent form, which owns it via `useTransition` — see Global Constraints), consumed by every form in Tasks 4-11 in place of a hand-rolled disabled/pending button. `logoutAction()`.

- [ ] **Step 1: Write the admin API fetch helper**

```typescript
import { cookies, headers } from "next/headers";

interface AdminApiResult<T> {
  data?: T;
  error?: string;
}

export async function adminApiFetch<T>(
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<AdminApiResult<T>> {
  const host = (await headers()).get("host") ?? "localhost:3000";
  const protocol = host.startsWith("localhost") || host.startsWith("127.0.0.1") ? "http" : "https";
  const cookieHeader = (await cookies())
    .getAll()
    .map((c) => `${c.name}=${c.value}`)
    .join("; ");

  const res = await fetch(`${protocol}://${host}${path}`, {
    method: options.method ?? "GET",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookieHeader,
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    cache: "no-store",
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { error: typeof json.error === "string" ? json.error : "Request failed." };
  }
  return { data: json as T };
}
```

- [ ] **Step 2: Write the shared submit button**

```tsx
"use client";

export function SubmitButton({
  pending,
  children,
  className,
}: {
  pending: boolean;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <button
      type="submit"
      disabled={pending}
      className={className ?? "rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50"}
    >
      {pending ? "Saving..." : children}
    </button>
  );
}
```

This is a plain presentational component — the parent form component owns its own pending
state via `useTransition` (see the Global Constraints section) and passes it down as a prop,
rather than `SubmitButton` deriving it via `useFormStatus()` context (which isn't available —
see Global Constraints).

- [ ] **Step 3: Write the login Server Action**

```typescript
"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function loginAction(formData: FormData): Promise<{ error?: string } | null> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    return { error: error.message };
  }

  redirect("/admin");
}
```

- [ ] **Step 4: Write the login page**

```tsx
"use client";

import { useState, useTransition } from "react";
import { loginAction } from "./actions";

export default function AdminLoginPage() {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await loginAction(formData);
      setError(result?.error);
    });
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4 p-6">
        <h1 className="text-xl font-semibold">Osteq Admin</h1>
        <input
          name="email"
          type="email"
          placeholder="Email"
          required
          className="w-full rounded border px-3 py-2"
        />
        <input
          name="password"
          type="password"
          placeholder="Password"
          required
          className="w-full rounded border px-3 py-2"
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button type="submit" disabled={isPending} className="w-full rounded bg-black px-3 py-2 text-white disabled:opacity-50">
          {isPending ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </div>
  );
}
```

- [ ] **Step 5: Write the logout action**

```typescript
"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function logoutAction() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/admin/login");
}
```

- [ ] **Step 6: Write the dashboard layout**

```tsx
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireStaffAccess } from "@/lib/auth";
import { logoutAction } from "./actions";

export default async function AdminDashboardLayout({ children }: { children: React.ReactNode }) {
  try {
    await requireStaffAccess();
  } catch {
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
```

- [ ] **Step 7: Write the `/admin` index redirect**

Middleware (`lib/supabase/middleware.ts`, already committed, not part of this plan) redirects
an authenticated visit to `/admin/login` to bare `/admin`, and this task's own `loginAction`
does the same on successful login — but no page exists at that route, which would 404
without this file. The spec defines no distinct "dashboard home" content, so this is a plain
server-side redirect to the first nav section rather than an invented overview screen.

```tsx
import { redirect } from "next/navigation";

export default function AdminIndexPage() {
  redirect("/admin/trade-applications");
}
```

- [ ] **Step 8: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "admin" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 9: Commit**

```bash
git add lib/admin app/admin
git commit -m "Add admin shell: API helper, submit button, login, dashboard layout"
```

---

### Task 4: Trade applications screen

**Files:**
- Create: `app/admin/(dashboard)/trade-applications/page.tsx`
- Create: `app/admin/(dashboard)/trade-applications/actions.ts`
- Create: `app/admin/(dashboard)/trade-applications/TradeApplicationActions.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`.

- [ ] **Step 1: Write the trade applications list page**

```tsx
import { prisma } from "@/lib/prisma";
import { TradeApplicationActions } from "./TradeApplicationActions";

export default async function TradeApplicationsPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const applications = await prisma.osteqTradeApplication.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true },
    orderBy: { createdAt: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Trade Applications</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Business</th>
            <th className="p-2">Type</th>
            <th className="p-2">Phone</th>
            <th className="p-2">Customer</th>
            <th className="p-2">Status</th>
            <th className="p-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          {applications.map((application) => (
            <tr key={application.id} className="border-b">
              <td className="p-2">{application.businessName}</td>
              <td className="p-2">{application.businessType}</td>
              <td className="p-2">{application.phone}</td>
              <td className="p-2">{application.customer.email}</td>
              <td className="p-2">{application.status}</td>
              <td className="p-2">
                {application.status === "PENDING" && (
                  <TradeApplicationActions applicationId={application.id} />
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Write the review Server Action**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function reviewTradeApplication(formData: FormData): Promise<{ error?: string } | null> {
  const applicationId = String(formData.get("applicationId") ?? "");
  const decision = String(formData.get("decision") ?? "");
  const rejectionReason = String(formData.get("rejectionReason") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/trade-applications/${applicationId}`, {
    method: "PATCH",
    body: { decision, rejectionReason: rejectionReason || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath("/admin/trade-applications");
  return null;
}
```

- [ ] **Step 3: Write the approve/reject client component**

Both the Approve and Reject forms submit through the same handler — `decision` travels as a
hidden field in each form's own `FormData`, so one `handleSubmit` correctly serves both.

```tsx
"use client";

import { useState, useTransition } from "react";
import { reviewTradeApplication } from "./actions";
import { SubmitButton } from "../SubmitButton";

export function TradeApplicationActions({ applicationId }: { applicationId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();
  const [showReject, setShowReject] = useState(false);

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await reviewTradeApplication(formData);
      setError(result?.error);
    });
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-2">
        <form onSubmit={handleSubmit}>
          <input type="hidden" name="applicationId" value={applicationId} />
          <input type="hidden" name="decision" value="APPROVED" />
          <SubmitButton pending={isPending} className="rounded bg-green-600 px-2 py-1 text-sm text-white disabled:opacity-50">
            Approve
          </SubmitButton>
        </form>
        <button
          type="button"
          onClick={() => setShowReject((v) => !v)}
          className="rounded bg-red-600 px-2 py-1 text-sm text-white"
        >
          Reject
        </button>
      </div>
      {showReject && (
        <form onSubmit={handleSubmit} className="flex gap-2">
          <input type="hidden" name="applicationId" value={applicationId} />
          <input type="hidden" name="decision" value="REJECTED" />
          <input name="rejectionReason" placeholder="Reason" className="rounded border px-2 py-1 text-sm" />
          <SubmitButton pending={isPending} className="rounded bg-red-600 px-2 py-1 text-sm text-white disabled:opacity-50">
            Confirm reject
          </SubmitButton>
        </form>
      )}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  );
}
```

- [ ] **Step 4: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "trade-applications" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 5: Commit**

```bash
git add "app/admin/(dashboard)/trade-applications"
git commit -m "Add trade applications admin screen"
```

---

### Task 5: Catalog — category list, create, edit

**Files:**
- Create: `app/admin/(dashboard)/catalog/page.tsx`
- Create: `app/admin/(dashboard)/catalog/actions.ts`
- Create: `app/admin/(dashboard)/catalog/CategoryForm.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`.
- Produces: `saveCategory` Server Action, `CategoryForm` component — consumed only within this task's own files.

- [ ] **Step 1: Write the category list page**

```tsx
import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { CategoryForm } from "./CategoryForm";

export default async function CatalogPage() {
  const categories = await prisma.osteqCategory.findMany({ orderBy: { name: "asc" } });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Catalog</h1>
      <ul className="mb-6 divide-y">
        {categories.map((category) => (
          <li key={category.id} className="flex items-center justify-between py-2">
            <Link href={`/admin/catalog/${category.id}`} className="underline">
              {category.name}
            </Link>
            <CategoryForm mode="edit" category={category} />
          </li>
        ))}
      </ul>
      <h2 className="mb-2 font-medium">Add category</h2>
      <CategoryForm mode="create" />
    </div>
  );
}
```

- [ ] **Step 2: Write the category Server Action**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function saveCategory(formData: FormData): Promise<{ error?: string } | null> {
  const categoryId = String(formData.get("categoryId") ?? "");
  const name = String(formData.get("name") ?? "");
  const slug = String(formData.get("slug") ?? "");

  const path = categoryId ? `/api/osteq/categories/${categoryId}` : "/api/osteq/categories";
  const { error } = await adminApiFetch(path, {
    method: categoryId ? "PATCH" : "POST",
    body: { name, slug },
  });
  if (error) {
    return { error };
  }

  revalidatePath("/admin/catalog");
  return null;
}
```

- [ ] **Step 3: Write the category form component**

```tsx
"use client";

import { useState, useTransition } from "react";
import type { OsteqCategory } from "@prisma/client";
import { saveCategory } from "./actions";
import { SubmitButton } from "../SubmitButton";

export function CategoryForm({
  mode,
  category,
}: {
  mode: "create" | "edit";
  category?: OsteqCategory;
}) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await saveCategory(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2">
      {category && <input type="hidden" name="categoryId" value={category.id} />}
      <input
        name="name"
        defaultValue={category?.name}
        placeholder="Name"
        required
        className="rounded border px-2 py-1 text-sm"
      />
      <input
        name="slug"
        defaultValue={category?.slug}
        placeholder="slug"
        required
        className="rounded border px-2 py-1 text-sm"
      />
      <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-sm text-white disabled:opacity-50">
        {mode === "create" ? "Add" : "Save"}
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 4: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "catalog/page\|catalog/actions\|CategoryForm" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 5: Commit**

```bash
git add "app/admin/(dashboard)/catalog/page.tsx" "app/admin/(dashboard)/catalog/actions.ts" "app/admin/(dashboard)/catalog/CategoryForm.tsx"
git commit -m "Add catalog category list, create, and edit"
```

---

### Task 6: Catalog — category detail (products) and create product

**Files:**
- Create: `app/admin/(dashboard)/catalog/[categoryId]/page.tsx`
- Create: `app/admin/(dashboard)/catalog/[categoryId]/actions.ts`
- Create: `app/admin/(dashboard)/catalog/[categoryId]/ProductForm.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`.

- [ ] **Step 1: Write the category detail page**

```tsx
import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductForm } from "./ProductForm";

export default async function CategoryDetailPage({
  params,
}: {
  params: { categoryId: string };
}) {
  const category = await prisma.osteqCategory.findUnique({ where: { id: params.categoryId } });
  if (!category) {
    notFound();
  }

  const products = await prisma.osteqProduct.findMany({
    where: { categoryId: params.categoryId },
    orderBy: { name: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">{category.name}</h1>
      <ul className="mb-6 divide-y">
        {products.map((product) => (
          <li key={product.id} className="py-2">
            <Link href={`/admin/catalog/products/${product.id}`} className="underline">
              {product.name}
            </Link>
            {!product.isActive && <span className="ml-2 text-xs text-gray-500">(inactive)</span>}
          </li>
        ))}
      </ul>
      <h2 className="mb-2 font-medium">Add product</h2>
      <ProductForm categoryId={category.id} />
    </div>
  );
}
```

- [ ] **Step 2: Write the create-product Server Action**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function createProduct(formData: FormData): Promise<{ error?: string } | null> {
  const categoryId = String(formData.get("categoryId") ?? "");
  const name = String(formData.get("name") ?? "");
  const slug = String(formData.get("slug") ?? "");
  const description = String(formData.get("description") ?? "");

  const { error } = await adminApiFetch("/api/osteq/products", {
    method: "POST",
    body: { categoryId, name, slug, description: description || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/${categoryId}`);
  return null;
}
```

- [ ] **Step 3: Write the product form component**

```tsx
"use client";

import { useState, useTransition } from "react";
import { createProduct } from "./actions";
import { SubmitButton } from "../../SubmitButton";

export function ProductForm({ categoryId }: { categoryId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await createProduct(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="categoryId" value={categoryId} />
      <input name="name" placeholder="Name" required className="rounded border px-2 py-1 text-sm" />
      <input name="slug" placeholder="slug" required className="rounded border px-2 py-1 text-sm" />
      <input name="description" placeholder="Description" className="rounded border px-2 py-1 text-sm" />
      <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-sm text-white disabled:opacity-50">
        Add
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 4: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "catalog/\[categoryId\]" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 5: Commit**

```bash
git add "app/admin/(dashboard)/catalog/[categoryId]"
git commit -m "Add catalog category detail and create-product screens"
```

---

### Task 7: Catalog — product detail (edit + variants)

**Files:**
- Create: `app/admin/(dashboard)/catalog/products/[id]/page.tsx`
- Create: `app/admin/(dashboard)/catalog/products/[id]/actions.ts`
- Create: `app/admin/(dashboard)/catalog/products/[id]/ProductEditForm.tsx`
- Create: `app/admin/(dashboard)/catalog/products/[id]/VariantForm.tsx`
- Create: `app/admin/(dashboard)/catalog/products/[id]/VariantEditForm.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`, `PATCH /variants/[variantId]` (Task 1).

- [ ] **Step 1: Write the product detail page**

```tsx
import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { ProductEditForm } from "./ProductEditForm";
import { VariantForm } from "./VariantForm";
import { VariantEditForm } from "./VariantEditForm";

export default async function ProductDetailPage({ params }: { params: { id: string } }) {
  const product = await prisma.osteqProduct.findUnique({
    where: { id: params.id },
    include: { variants: { orderBy: { sku: "asc" } } },
  });
  if (!product) {
    notFound();
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">{product.name}</h1>
      <ProductEditForm product={product} />

      <h2 className="mb-2 mt-6 font-medium">Variants</h2>
      <table className="mb-4 w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">SKU</th>
            <th className="p-2">Attributes</th>
            <th className="p-2">Retail (paise)</th>
            <th className="p-2">Trade (paise)</th>
            <th className="p-2">Stock</th>
            <th className="p-2">Active</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {product.variants.map((variant) => (
            <VariantEditForm key={variant.id} productId={product.id} variant={variant} />
          ))}
        </tbody>
      </table>

      <h2 className="mb-2 font-medium">Add variant</h2>
      <VariantForm productId={product.id} />
    </div>
  );
}
```

- [ ] **Step 2: Write the Server Actions**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateProduct(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const name = String(formData.get("name") ?? "");
  const description = String(formData.get("description") ?? "");
  const isActive = formData.get("isActive") === "on";

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}`, {
    method: "PATCH",
    body: { name, description, isActive },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  return null;
}

export async function createVariant(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const sku = String(formData.get("sku") ?? "");
  const attributeName = String(formData.get("attributeName") ?? "").trim();
  const attributeValue = String(formData.get("attributeValue") ?? "").trim();
  const retailPriceInPaise = Number(formData.get("retailPriceInPaise"));
  const tradePriceInPaise = Number(formData.get("tradePriceInPaise"));
  const stockQuantity = Number(formData.get("stockQuantity"));

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}/variants`, {
    method: "POST",
    body: {
      sku,
      attributes: attributeName && attributeValue ? { [attributeName]: attributeValue } : {},
      retailPriceInPaise,
      tradePriceInPaise,
      stockQuantity,
    },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  return null;
}

export async function updateVariant(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const variantId = String(formData.get("variantId") ?? "");
  const retailPriceInPaise = Number(formData.get("retailPriceInPaise"));
  const tradePriceInPaise = Number(formData.get("tradePriceInPaise"));
  const stockQuantity = Number(formData.get("stockQuantity"));
  const isActive = formData.get("isActive") === "on";

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}/variants/${variantId}`, {
    method: "PATCH",
    body: { retailPriceInPaise, tradePriceInPaise, stockQuantity, isActive },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  return null;
}
```

- [ ] **Step 3: Write the product edit form**

```tsx
"use client";

import { useState, useTransition } from "react";
import type { OsteqProduct } from "@prisma/client";
import { updateProduct } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function ProductEditForm({ product }: { product: OsteqProduct }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await updateProduct(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2 rounded border p-4">
      <input type="hidden" name="productId" value={product.id} />
      <label className="text-sm">
        Name
        <input
          name="name"
          defaultValue={product.name}
          required
          className="mt-1 w-full rounded border px-2 py-1 text-sm"
        />
      </label>
      <label className="text-sm">
        Description
        <textarea
          name="description"
          defaultValue={product.description ?? ""}
          className="mt-1 w-full rounded border px-2 py-1 text-sm"
        />
      </label>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="isActive" defaultChecked={product.isActive} />
        Active
      </label>
      <SubmitButton pending={isPending} className="w-fit rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Save
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 4: Write the add-variant form**

```tsx
"use client";

import { useState, useTransition } from "react";
import { createVariant } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function VariantForm({ productId }: { productId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await createVariant(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="productId" value={productId} />
      <input name="sku" placeholder="SKU" required className="rounded border px-2 py-1 text-sm" />
      <input
        name="attributeName"
        placeholder="Attribute name (e.g. length)"
        className="rounded border px-2 py-1 text-sm"
      />
      <input
        name="attributeValue"
        placeholder="Attribute value (e.g. 6ft)"
        className="rounded border px-2 py-1 text-sm"
      />
      <input
        name="retailPriceInPaise"
        type="number"
        placeholder="Retail (paise)"
        required
        className="w-32 rounded border px-2 py-1 text-sm"
      />
      <input
        name="tradePriceInPaise"
        type="number"
        placeholder="Trade (paise)"
        required
        className="w-32 rounded border px-2 py-1 text-sm"
      />
      <input
        name="stockQuantity"
        type="number"
        placeholder="Stock"
        defaultValue={0}
        className="w-24 rounded border px-2 py-1 text-sm"
      />
      <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-sm text-white disabled:opacity-50">
        Add
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 5: Write the per-variant edit row**

The `onSubmit` handler's `new FormData(event.currentTarget)` still correctly picks up every
input associated with this `<form>` via the `form={formId}` attribute, exactly as it would
for a native form submission — this behavior comes from the browser's form-association
model, not from `useFormState`, so the earlier table-row-form pattern is unaffected by
this plan's hook change.

```tsx
"use client";

import { useState, useTransition } from "react";
import type { OsteqProductVariant } from "@prisma/client";
import { updateVariant } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function VariantEditForm({
  productId,
  variant,
}: {
  productId: string;
  variant: OsteqProductVariant;
}) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();
  const formId = `variant-form-${variant.id}`;

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await updateVariant(formData);
      setError(result?.error);
    });
  }

  return (
    <tr className="border-b">
      <td className="p-2">{variant.sku}</td>
      <td className="p-2">{JSON.stringify(variant.attributes)}</td>
      <td className="p-2">
        <input
          name="retailPriceInPaise"
          type="number"
          defaultValue={variant.retailPriceInPaise}
          form={formId}
          className="w-24 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input
          name="tradePriceInPaise"
          type="number"
          defaultValue={variant.tradePriceInPaise}
          form={formId}
          className="w-24 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input
          name="stockQuantity"
          type="number"
          defaultValue={variant.stockQuantity}
          form={formId}
          className="w-20 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input type="checkbox" name="isActive" defaultChecked={variant.isActive} form={formId} />
      </td>
      <td className="p-2">
        <form id={formId} onSubmit={handleSubmit}>
          <input type="hidden" name="productId" value={productId} />
          <input type="hidden" name="variantId" value={variant.id} />
          <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-xs text-white disabled:opacity-50">
            Save
          </SubmitButton>
        </form>
        {error && <span className="ml-2 text-xs text-red-600">{error}</span>}
      </td>
    </tr>
  );
}
```

Note on the `form={formId}` attribute: the inputs for retail/trade price, stock, and active
live in earlier `<td>`s, while the `<form>` element itself lives only in the last `<td>` (a
`<form>` cannot wrap multiple `<td>` siblings directly under a `<tr>` — that's invalid table
markup). HTML5's `form` attribute lets an input outside a `<form>` still submit as part of it
by referencing the form's `id`; this is the correct, valid pattern for a form-per-table-row.

- [ ] **Step 6: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "catalog/products/\[id\]" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 7: Commit**

```bash
git add "app/admin/(dashboard)/catalog/products/[id]"
git commit -m "Add product detail screen: edit product, add/edit variants"
```

---

### Task 8: Quotes list

**Files:**
- Create: `app/admin/(dashboard)/quotes/page.tsx`

**Interfaces:**
- Consumes: `prisma`.

- [ ] **Step 1: Write the quotes list page**

```tsx
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export default async function QuotesPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const quotes = await prisma.osteqQuote.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true, items: true },
    orderBy: { createdAt: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Quotes</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Customer</th>
            <th className="p-2">Items</th>
            <th className="p-2">Status</th>
            <th className="p-2">Created</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {quotes.map((quote) => (
            <tr key={quote.id} className="border-b">
              <td className="p-2">{quote.customer.email}</td>
              <td className="p-2">{quote.items.length}</td>
              <td className="p-2">{quote.status}</td>
              <td className="p-2">{quote.createdAt.toLocaleDateString()}</td>
              <td className="p-2">
                <Link href={`/admin/quotes/${quote.id}`} className="underline">
                  View
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "quotes/page" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 3: Commit**

```bash
git add "app/admin/(dashboard)/quotes/page.tsx"
git commit -m "Add quotes list admin screen"
```

---

### Task 9: Quote detail (pricing + messages)

**Files:**
- Create: `app/admin/(dashboard)/quotes/[id]/page.tsx`
- Create: `app/admin/(dashboard)/quotes/[id]/actions.ts`
- Create: `app/admin/(dashboard)/quotes/[id]/PriceForm.tsx`
- Create: `app/admin/(dashboard)/quotes/[id]/MessageForm.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`.

- [ ] **Step 1: Write the quote detail page**

```tsx
import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { PriceForm } from "./PriceForm";
import { MessageForm } from "./MessageForm";

const PRICEABLE_STATUSES = ["SUBMITTED", "UNDER_REVIEW", "REVISION_REQUESTED"];

export default async function QuoteDetailPage({ params }: { params: { id: string } }) {
  const quote = await prisma.osteqQuote.findUnique({
    where: { id: params.id },
    include: {
      customer: true,
      items: { include: { variant: true } },
      messages: { orderBy: { createdAt: "asc" } },
    },
  });
  if (!quote) {
    notFound();
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Quote for {quote.customer.email}</h1>
      <p className="mb-4 text-sm">Status: {quote.status}</p>

      <h2 className="mb-2 font-medium">Line items</h2>
      {PRICEABLE_STATUSES.includes(quote.status) ? (
        <PriceForm quoteId={quote.id} items={quote.items} />
      ) : (
        <ul className="mb-6 divide-y text-sm">
          {quote.items.map((item) => (
            <li key={item.id} className="py-2">
              {item.variant?.sku ?? item.description} — qty {item.quantity} —{" "}
              {item.quotedUnitPriceInPaise != null
                ? `${item.quotedUnitPriceInPaise} paise`
                : "not priced"}
            </li>
          ))}
        </ul>
      )}

      <h2 className="mb-2 mt-6 font-medium">Messages</h2>
      <ul className="mb-4 divide-y text-sm">
        {quote.messages.map((message) => (
          <li key={message.id} className="py-2">
            <span className="font-medium">{message.authorProfileId ? "Staff" : "Customer"}:</span>{" "}
            {message.body}
          </li>
        ))}
      </ul>
      <MessageForm quoteId={quote.id} />
    </div>
  );
}
```

- [ ] **Step 2: Write the Server Actions**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function priceQuote(formData: FormData): Promise<{ error?: string } | null> {
  const quoteId = String(formData.get("quoteId") ?? "");
  const itemIds = formData.getAll("itemId").map(String);
  const lines = itemIds
    .map((itemId) => {
      const price = formData.get(`price-${itemId}`);
      const quotedUnitPriceInPaise = Number(price);
      return Number.isFinite(quotedUnitPriceInPaise) ? { itemId, quotedUnitPriceInPaise } : null;
    })
    .filter((line): line is { itemId: string; quotedUnitPriceInPaise: number } => line !== null);

  const { error } = await adminApiFetch(`/api/osteq/quotes/${quoteId}/price`, {
    method: "PATCH",
    body: { lines },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/quotes/${quoteId}`);
  return null;
}

export async function sendQuoteMessage(formData: FormData): Promise<{ error?: string } | null> {
  const quoteId = String(formData.get("quoteId") ?? "");
  const body = String(formData.get("body") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/quotes/${quoteId}/messages`, {
    method: "POST",
    body: { body },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/quotes/${quoteId}`);
  return null;
}
```

- [ ] **Step 3: Write the pricing form**

```tsx
"use client";

import { useState, useTransition } from "react";
import type { OsteqQuoteItem, OsteqProductVariant } from "@prisma/client";
import { priceQuote } from "./actions";
import { SubmitButton } from "../../SubmitButton";

type ItemWithVariant = OsteqQuoteItem & { variant: OsteqProductVariant | null };

export function PriceForm({ quoteId, items }: { quoteId: string; items: ItemWithVariant[] }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await priceQuote(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="mb-6 flex flex-col gap-2">
      <input type="hidden" name="quoteId" value={quoteId} />
      {items.map((item) => (
        <div key={item.id} className="flex items-center gap-2 text-sm">
          <input type="hidden" name="itemId" value={item.id} />
          <span className="w-64">
            {item.variant?.sku ?? item.description} — qty {item.quantity}
          </span>
          <input
            name={`price-${item.id}`}
            type="number"
            placeholder="Unit price (paise)"
            defaultValue={item.quotedUnitPriceInPaise ?? undefined}
            className="w-40 rounded border px-2 py-1"
          />
        </div>
      ))}
      <SubmitButton pending={isPending} className="w-fit rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Save prices &amp; mark quoted
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 4: Write the message form**

```tsx
"use client";

import { useState, useTransition } from "react";
import { sendQuoteMessage } from "./actions";
import { SubmitButton } from "../../SubmitButton";

export function MessageForm({ quoteId }: { quoteId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await sendQuoteMessage(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2">
      <input type="hidden" name="quoteId" value={quoteId} />
      <input name="body" placeholder="Message" required className="flex-1 rounded border px-2 py-1 text-sm" />
      <SubmitButton pending={isPending} className="rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Send
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 5: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "quotes/\[id\]" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 6: Commit**

```bash
git add "app/admin/(dashboard)/quotes/[id]"
git commit -m "Add quote detail screen: pricing and message thread"
```

---

### Task 10: Orders list

**Files:**
- Create: `app/admin/(dashboard)/orders/page.tsx`

**Interfaces:**
- Consumes: `prisma`.

- [ ] **Step 1: Write the orders list page**

```tsx
import { prisma } from "@/lib/prisma";
import Link from "next/link";

export default async function OrdersPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const orders = await prisma.osteqOrder.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true },
    orderBy: { createdAt: "desc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Orders</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Customer</th>
            <th className="p-2">Total (paise)</th>
            <th className="p-2">Status</th>
            <th className="p-2">Created</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {orders.map((order) => (
            <tr key={order.id} className="border-b">
              <td className="p-2">{order.customer.email}</td>
              <td className="p-2">{order.totalInPaise}</td>
              <td className="p-2">{order.status}</td>
              <td className="p-2">{order.createdAt.toLocaleDateString()}</td>
              <td className="p-2">
                <Link href={`/admin/orders/${order.id}`} className="underline">
                  View
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "orders/page" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 3: Commit**

```bash
git add "app/admin/(dashboard)/orders/page.tsx"
git commit -m "Add orders list admin screen"
```

---

### Task 11: Order detail (status update)

**Files:**
- Create: `app/admin/(dashboard)/orders/[id]/page.tsx`
- Create: `app/admin/(dashboard)/orders/[id]/actions.ts`
- Create: `app/admin/(dashboard)/orders/[id]/StatusForm.tsx`

**Interfaces:**
- Consumes: `adminApiFetch`, `SubmitButton` (Task 3), `prisma`.

- [ ] **Step 1: Write the order detail page**

```tsx
import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { StatusForm } from "./StatusForm";

export default async function OrderDetailPage({ params }: { params: { id: string } }) {
  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { customer: true, items: { include: { variant: true } } },
  });
  if (!order) {
    notFound();
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Order for {order.customer.email}</h1>
      <p className="mb-2 text-sm">Shipping to: {order.shippingAddress}</p>
      <p className="mb-4 text-sm">Total: {order.totalInPaise} paise</p>

      <h2 className="mb-2 font-medium">Items</h2>
      <ul className="mb-6 divide-y text-sm">
        {order.items.map((item) => (
          <li key={item.id} className="py-2">
            {item.variant.sku} — qty {item.quantity} — {item.unitPriceInPaise} paise each
          </li>
        ))}
      </ul>

      <h2 className="mb-2 font-medium">Status</h2>
      <StatusForm order={order} />
    </div>
  );
}
```

- [ ] **Step 2: Write the status update Server Action**

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateOrderStatus(formData: FormData): Promise<{ error?: string } | null> {
  const orderId = String(formData.get("orderId") ?? "");
  const status = String(formData.get("status") ?? "");
  const trackingNumber = String(formData.get("trackingNumber") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/orders/${orderId}/status`, {
    method: "PATCH",
    body: { status, trackingNumber: trackingNumber || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/orders/${orderId}`);
  return null;
}
```

- [ ] **Step 3: Write the status form**

```tsx
"use client";

import { useState, useTransition } from "react";
import type { OsteqOrder } from "@prisma/client";
import { updateOrderStatus } from "./actions";
import { SubmitButton } from "../../SubmitButton";

const STATUSES = ["PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED"];

export function StatusForm({ order }: { order: OsteqOrder }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await updateOrderStatus(formData);
      setError(result?.error);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="orderId" value={order.id} />
      <select name="status" defaultValue={order.status} className="rounded border px-2 py-1 text-sm">
        {STATUSES.map((status) => (
          <option key={status} value={status}>
            {status}
          </option>
        ))}
      </select>
      <input
        name="trackingNumber"
        defaultValue={order.trackingNumber ?? ""}
        placeholder="Tracking number"
        className="rounded border px-2 py-1 text-sm"
      />
      <SubmitButton pending={isPending} className="rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Update
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
```

- [ ] **Step 4: Verify it compiles**

```bash
npx tsc --noEmit 2>&1 | grep -i "orders/\[id\]" || echo "no errors"
```
Expected: `no errors`.

- [ ] **Step 5: Commit**

```bash
git add "app/admin/(dashboard)/orders/[id]"
git commit -m "Add order detail screen: status and tracking update"
```

---

### Task 12: Manual verification

**Files:** None — verification only.

**Interfaces:** None.

This repo already has a local Supabase instance, `npm run dev`, a seeded test product, and a
test staff account (`staff@osteq.test` / `TestStaff123!`) running from the customer app's
device-testing session — no new setup needed, just a browser.

- [ ] **Step 1: Full build check**

```bash
npx tsc --noEmit 2>&1 | tail -20
npm run build 2>&1 | tail -40
```
Expected: `tsc` outputs nothing (clean); `npm run build` ends with `Compiled successfully` and
the route list includes every new `/admin/*` page from this plan.

- [ ] **Step 2: Log in**

With the dev server running, open `http://localhost:3000/admin` in a browser. Expected:
redirected to `/admin/login` (no session yet). Log in as `staff@osteq.test` /
`TestStaff123!`. Expected: redirected to `/admin`, which redirects into the dashboard layout
showing the nav.

- [ ] **Step 3: Trade applications**

Navigate to Trade Applications. If no application exists yet, submit one from the customer
app first (or directly via curl against `/api/osteq/trade-applications` using a customer
bearer token). Approve it. Expected: status flips to `APPROVED`, Approve/Reject buttons
disappear for that row (no longer `PENDING`).

- [ ] **Step 4: Catalog**

Navigate to Catalog. Add a new category. Open it, add a product. Open the product, edit its
description, add a variant, then edit that variant's price and stock. Expected: every save
succeeds and the page reflects the new values after each action (via `revalidatePath`).

- [ ] **Step 5: Quotes**

Submit a quote from the customer app (or curl) referencing the seeded product. In the admin
Quotes list, open it, enter a unit price for the line item, save. Expected: quote status
becomes `QUOTED`. Post a message. Expected: it appears in the thread.

- [ ] **Step 6: Orders**

Place an order from the customer app (checkout) or accept the quote from Step 5 (which
converts it to an order). In the admin Orders list, open the resulting order, change its
status to `SHIPPED` with a tracking number. Expected: save succeeds, detail page reflects the
new status/tracking number.

- [ ] **Step 7: Log out**

Click "Log out" in the nav. Expected: redirected to `/admin/login`; navigating back to
`/admin` redirects to login again (session cleared).
