# Live Delivery Tracking + Push + Invoice PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let staff attach a Rapido/Porter tracking link to an order (viewable live in-app), push-notify the customer the moment an order goes out for delivery, and let staff upload a PDF invoice the customer can download.

**Architecture:** Three additive slices sharing one order-detail feature area: (1) a `trackingUrl` column + a `webview_flutter` viewport in the Flutter app, (2) an `fcmToken` column + `firebase-admin` on the Next.js backend + `firebase_messaging` in Flutter, (3) an `invoicePdfPath` column + a private Supabase Storage bucket + signed-URL download endpoint. All three build on the existing order status/detail admin pages and the existing customer-app orders feature.

**Tech Stack:** Next.js 14 (App Router) + TypeScript + Prisma + Supabase (self-hosted, Postgres + Storage) on the backend; Flutter (Riverpod + go_router + Dio) on the customer app; Firebase Cloud Messaging for push.

## Global Constraints

- No automated test framework exists anywhere in this repo today (no `*.test.ts`, no `*_test.dart` beyond Flutter's default template absence) — every task verifies via `npx tsc --noEmit`, `flutter analyze`, and documented manual curl/UI checks, not new test files. This matches the existing project convention; do not introduce a test framework as a side effect of this plan.
- This worktree has no live Postgres connection (self-hosted Supabase runs on the project's VPS, no `.env.local` here). Run `prisma generate`/`prisma validate` with placeholder `DATABASE_URL`/`DIRECT_URL` env vars (they don't need a real connection). The hand-written migration SQL this plan produces still needs to be applied on the VPS by the user — flag this at the end, don't attempt to apply it from here.
- Store only relative Supabase Storage paths server-side, never full URLs — existing convention (see `lib/supabase/storage.ts`'s doc comment). The Flutter app and admin panel each resolve paths against their own known base URL.
- Notification helpers are fire-and-forget: catch and log, never throw — existing convention in `lib/osteq/notifications.ts`'s `sendEmail`.
- Three steps in this plan are **MANUAL STEPS** the agent cannot perform (no Firebase console access, no VPS Supabase Studio access, no Xcode GUI): creating the Firebase project, creating the `order-invoices` bucket on the production Supabase instance, and enabling the iOS Push Notifications capability in Xcode. Each is called out explicitly where it blocks a later step — code is written so the app still builds and runs with these unconfigured (push/tracking stay inert, everything else works).

---

### Task 1: Schema migration — trackingUrl, OUT_FOR_DELIVERY rename, fcmToken, invoicePdfPath

**Files:**
- Modify: `prisma/schema.prisma`
- Create: `prisma/migrations/20260922120000_add_tracking_push_invoice/migration.sql`

**Interfaces:**
- Produces: `OsteqOrder.trackingUrl: string | null`, `OsteqOrder.invoicePdfPath: string | null`, `OsteqOrderStatus` enum value `OUT_FOR_DELIVERY` (replacing `SHIPPED`), `OsteqCustomerProfile.fcmToken: string | null`. All later backend/Flutter tasks reference these exact names.

- [ ] **Step 1: Edit `prisma/schema.prisma`**

Find the `OsteqOrderStatus` enum (currently):

```prisma
enum OsteqOrderStatus {
  PROCESSING
  SHIPPED
  DELIVERED
  CANCELLED
}
```

Replace with:

```prisma
enum OsteqOrderStatus {
  PROCESSING
  OUT_FOR_DELIVERY
  DELIVERED
  CANCELLED
}
```

Find the `OsteqOrder` model:

```prisma
model OsteqOrder {
  id               String           @id @default(uuid())
  customerId       String
  status           OsteqOrderStatus @default(PROCESSING)
  shippingAddress  String
  trackingNumber   String?
  totalInRupees    Decimal          @db.Decimal(10, 2)
  createdAt        DateTime         @default(now())
```

Replace with:

```prisma
model OsteqOrder {
  id               String           @id @default(uuid())
  customerId       String
  status           OsteqOrderStatus @default(PROCESSING)
  shippingAddress  String
  trackingNumber   String?
  trackingUrl      String?
  invoicePdfPath   String?
  totalInRupees    Decimal          @db.Decimal(10, 2)
  createdAt        DateTime         @default(now())
```

Find the `OsteqCustomerProfile` model:

```prisma
model OsteqCustomerProfile {
  id           String             @id
  email        String             @unique
  businessName String?
  businessType String?
  phone        String?
  accountStatus OsteqAccountStatus @default(PENDING)
  createdAt    DateTime           @default(now())
```

Replace with:

```prisma
model OsteqCustomerProfile {
  id           String             @id
  email        String             @unique
  businessName String?
  businessType String?
  phone        String?
  fcmToken     String?
  accountStatus OsteqAccountStatus @default(PENDING)
  createdAt    DateTime           @default(now())
```

- [ ] **Step 2: Validate the schema (no live DB needed)**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx prisma validate`
Expected: `The schema at prisma\schema.prisma is valid`

- [ ] **Step 3: Write the migration SQL by hand**

Create `prisma/migrations/20260922120000_add_tracking_push_invoice/migration.sql`:

```sql
-- AlterEnum
ALTER TYPE "OsteqOrderStatus" RENAME VALUE 'SHIPPED' TO 'OUT_FOR_DELIVERY';

-- AlterTable
ALTER TABLE "osteq_orders" ADD COLUMN     "trackingUrl" TEXT,
ADD COLUMN     "invoicePdfPath" TEXT;

-- AlterTable
ALTER TABLE "osteq_customer_profiles" ADD COLUMN     "fcmToken" TEXT;
```

- [ ] **Step 4: Regenerate the Prisma client**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx prisma generate`
Expected: `Generated Prisma Client` with no errors — this updates the TypeScript types (`OsteqOrder.trackingUrl`, etc.) used by every later backend task.

- [ ] **Step 5: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors (existing code references `"SHIPPED"` as a string literal nowhere outside `StatusForm.tsx`/`status/route.ts`, which Task 3 updates — if tsc surfaces any other `"SHIPPED"` string-literal type error here, fix it inline as part of this task).

- [ ] **Step 6: Commit**

```bash
git add prisma/schema.prisma prisma/migrations/20260922120000_add_tracking_push_invoice
git commit -m "Add trackingUrl, invoicePdfPath, fcmToken columns; rename SHIPPED to OUT_FOR_DELIVERY"
```

---

### Task 2: Order status endpoint — trackingUrl + auto out-for-delivery

**Files:**
- Modify: `app/api/osteq/orders/[id]/status/route.ts`

**Interfaces:**
- Consumes: `OsteqOrder.trackingUrl`, `OsteqOrderStatus` (Task 1).
- Produces: `PATCH /api/osteq/orders/[id]/status` now accepts an optional `trackingUrl: string | null` body field in addition to the existing `status`/`trackingNumber`.

- [ ] **Step 1: Replace the route file**

Replace the full contents of `app/api/osteq/orders/[id]/status/route.ts` with:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { notifyOrderStatusChange } from "@/lib/osteq/notifications";

const VALID_STATUSES = new Set(["PROCESSING", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"]);

function parseTrackingUrl(value: unknown): string | null | undefined {
  if (value === null || value === "") return null;
  if (typeof value !== "string") return undefined;
  try {
    new URL(value);
    return value;
  } catch {
    return undefined;
  }
}

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  const body = await request.json();
  let status = body.status;
  const trackingNumber =
    body.trackingNumber === null || body.trackingNumber === ""
      ? null
      : typeof body.trackingNumber === "string"
        ? body.trackingNumber
        : undefined;

  const trackingUrlProvided = body.trackingUrl !== undefined;
  const trackingUrl = trackingUrlProvided ? parseTrackingUrl(body.trackingUrl) : undefined;
  if (trackingUrlProvided && trackingUrl === undefined) {
    return NextResponse.json({ error: "trackingUrl must be a valid URL." }, { status: 400 });
  }

  // Pasting a tracking link is what actually marks an order out for delivery — auto-flip
  // the status whenever a link is being set for the first time, regardless of what status
  // the admin form submitted, unless the order is already DELIVERED/CANCELLED.
  if (
    trackingUrl != null &&
    existing.trackingUrl == null &&
    existing.status !== "DELIVERED" &&
    existing.status !== "CANCELLED"
  ) {
    status = "OUT_FOR_DELIVERY";
  }

  if (typeof status !== "string" || !VALID_STATUSES.has(status)) {
    return NextResponse.json({ error: "A valid status is required." }, { status: 400 });
  }

  const order = await prisma.osteqOrder.update({
    where: { id: params.id },
    data: {
      status: status as "PROCESSING" | "OUT_FOR_DELIVERY" | "DELIVERED" | "CANCELLED",
      trackingNumber,
      ...(trackingUrlProvided ? { trackingUrl } : {}),
    },
  });

  notifyOrderStatusChange(order);

  return NextResponse.json({ order });
}
```

- [ ] **Step 2: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add "app/api/osteq/orders/[id]/status/route.ts"
git commit -m "Accept trackingUrl on order status update; auto-flip to OUT_FOR_DELIVERY"
```

---

### Task 3: Device-token registration endpoint

**Files:**
- Create: `app/api/osteq/customers/device-token/route.ts`

**Interfaces:**
- Consumes: `requireOsteqCustomerAccess(request)` from `lib/osteq/auth.ts` (returns `{ customerId, email }`), `OsteqCustomerProfile.fcmToken` (Task 1).
- Produces: `POST /api/osteq/customers/device-token` with body `{ fcmToken: string }` → `{ ok: true }`. Consumed by Flutter Task 10.

- [ ] **Step 1: Create the route**

Create `app/api/osteq/customers/device-token/route.ts`:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const fcmToken = typeof body.fcmToken === "string" ? body.fcmToken : "";
  if (!fcmToken) {
    return NextResponse.json({ error: "fcmToken is required." }, { status: 400 });
  }

  await prisma.osteqCustomerProfile.update({
    where: { id: customerId },
    data: { fcmToken },
  });

  return NextResponse.json({ ok: true });
}
```

- [ ] **Step 2: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add "app/api/osteq/customers/device-token/route.ts"
git commit -m "Add device-token registration endpoint for push notifications"
```

---

### Task 4: firebase-admin push helper wired into order status notifications

**Files:**
- Modify: `package.json`
- Modify: `lib/osteq/notifications.ts`
- Modify: `.env.example`

**Interfaces:**
- Produces: `sendPush(fcmToken, title, body, data)` in `lib/osteq/notifications.ts`, called automatically from `notifyOrderStatusChange` when `order.status === "OUT_FOR_DELIVERY"`.

- [ ] **Step 1: Add the dependency**

In `package.json`, add to `"dependencies"` (alphabetically, after `"@supabase/supabase-js"`):

```json
    "firebase-admin": "^12.6.0",
```

Run: `npm install`
Expected: `firebase-admin` and its transitive deps added to `package-lock.json`, exit code 0.

- [ ] **Step 2: Add `sendPush` and wire it into `notifyOrderStatusChange`**

In `lib/osteq/notifications.ts`, add these imports at the top (after the existing `import { prisma } from "@/lib/prisma";`):

```typescript
import { initializeApp, cert, getApps, type App } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
```

Add this function after `sendEmail` (before `notifyTradeApplicationDecision`):

```typescript
function firebaseApp(): App | null {
  if (getApps().length > 0) return getApps()[0];
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) return null;
  return initializeApp({ credential: cert(JSON.parse(json)) });
}

/**
 * Same fire-and-forget contract as sendEmail above — the triggering DB write is always
 * the source of truth, this only ever logs on failure.
 */
async function sendPush(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const app = firebaseApp();
  if (!app) {
    console.log(`[osteq notification] No FIREBASE_SERVICE_ACCOUNT_JSON configured. Push skipped: ${title}`);
    return;
  }
  try {
    await getMessaging(app).send({ token: fcmToken, notification: { title, body }, data });
  } catch (err) {
    console.error("Osteq push notification failed:", err);
  }
}
```

Replace `notifyOrderStatusChange` (currently):

```typescript
export async function notifyOrderStatusChange(order: OsteqOrder): Promise<void> {
  try {
    const customer = await prisma.osteqCustomerProfile.findUnique({ where: { id: order.customerId } });
    if (!customer) return;
    await sendEmail(customer.email, "Your Osteq order status changed", `Order ${order.id} is now ${order.status}.`);
  } catch (err) {
    console.error("Osteq notification failed (order status change):", err);
  }
}
```

with:

```typescript
export async function notifyOrderStatusChange(order: OsteqOrder): Promise<void> {
  try {
    const customer = await prisma.osteqCustomerProfile.findUnique({ where: { id: order.customerId } });
    if (!customer) return;
    await sendEmail(customer.email, "Your Osteq order status changed", `Order ${order.id} is now ${order.status}.`);

    if (order.status === "OUT_FOR_DELIVERY" && customer.fcmToken) {
      await sendPush(
        customer.fcmToken,
        "Your order is out for delivery",
        `Order ${order.id.slice(0, 8).toUpperCase()} is on its way.`,
        { orderId: order.id, trackingUrl: order.trackingUrl ?? "" },
      );
    }
  } catch (err) {
    console.error("Osteq notification failed (order status change):", err);
  }
}
```

- [ ] **Step 3: Document the new env var**

In `.env.example`, after the `RESEND_API_KEY=` line, add:

```
# Optional — push notifications (order out-for-delivery). Without this, pushes just log
# to the console. This is a Firebase service account JSON (Firebase console -> Project
# settings -> Service accounts -> Generate new private key), pasted as a single-line
# JSON string. Firebase is used purely as the push delivery pipe; no other Firebase
# product is used.
FIREBASE_SERVICE_ACCOUNT_JSON=
```

- [ ] **Step 4: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json lib/osteq/notifications.ts .env.example
git commit -m "Send FCM push when an order goes out for delivery"
```

---

### Task 5: Admin UI — status rename + tracking link field

**Files:**
- Modify: `app/admin/(dashboard)/orders/[id]/StatusForm.tsx`
- Modify: `app/admin/(dashboard)/orders/[id]/actions.ts`

**Interfaces:**
- Consumes: `PATCH /api/osteq/orders/[id]/status` with `trackingUrl` (Task 2).

- [ ] **Step 1: Update `StatusForm.tsx`**

Change the `STATUSES` array (line 8):

```typescript
const STATUSES = ["PROCESSING", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"];
```

Add a `trackingUrl` input after the existing `trackingNumber` input (after the `<input name="trackingNumber" .../>` block, before `<SubmitButton>`):

```tsx
      <input
        name="trackingUrl"
        defaultValue={order.trackingUrl ?? ""}
        placeholder="Tracking link (Rapido/Porter)"
        className="rounded border px-2 py-1 text-sm"
      />
```

- [ ] **Step 2: Update `actions.ts`**

Replace the full contents of `app/admin/(dashboard)/orders/[id]/actions.ts` with:

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateOrderStatus(formData: FormData): Promise<{ error?: string } | null> {
  const orderId = String(formData.get("orderId") ?? "");
  const status = String(formData.get("status") ?? "");
  const trackingNumber = String(formData.get("trackingNumber") ?? "");
  const trackingUrl = String(formData.get("trackingUrl") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/orders/${orderId}/status`, {
    method: "PATCH",
    body: {
      status,
      trackingNumber: trackingNumber.trim() === "" ? null : trackingNumber.trim(),
      trackingUrl: trackingUrl.trim() === "" ? null : trackingUrl.trim(),
    },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/orders/${orderId}`);
  revalidatePath("/admin/orders");
  return null;
}
```

- [ ] **Step 3: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add "app/admin/(dashboard)/orders/[id]/StatusForm.tsx" "app/admin/(dashboard)/orders/[id]/actions.ts"
git commit -m "Admin: rename SHIPPED to OUT_FOR_DELIVERY, add tracking link field"
```

---

### Task 6: Invoice PDF upload/delete endpoint + private storage bucket

**Files:**
- Create: `app/api/osteq/orders/[id]/invoice-pdf/route.ts`
- Modify: `supabase/config.toml`

**Interfaces:**
- Consumes: `OsteqOrder.invoicePdfPath` (Task 1), `createAdminClient()` from `lib/supabase/admin.ts`.
- Produces: `POST /api/osteq/orders/[id]/invoice-pdf` (multipart `file`) → `{ order }`; `DELETE /api/osteq/orders/[id]/invoice-pdf` → `{ order }`. Bucket name `order-invoices`, object path `${orderId}/invoice.pdf`.

- [ ] **Step 1: Add the bucket to `supabase/config.toml`**

After the existing `[storage.buckets.product-images]` block, add:

```toml
# Private bucket for staff-uploaded invoice PDFs — access only via short-lived signed URLs
# (app/api/osteq/orders/[id]/invoice-download), since these are a customer's billing
# documents and must not be publicly readable like product-images.
[storage.buckets.order-invoices]
public = false
file_size_limit = "20MiB"
allowed_mime_types = ["application/pdf"]
```

**MANUAL STEP (not executable here):** this config file only provisions buckets for a local `supabase start` dev stack. The production self-hosted instance on the VPS needs this bucket created by hand in Supabase Studio: Storage → New bucket → name `order-invoices` → Public toggle **OFF** → file size limit 20MB → allowed MIME type `application/pdf`. Note this in the final verification task.

- [ ] **Step 2: Create the upload/delete route**

Create `app/api/osteq/orders/[id]/invoice-pdf/route.ts`:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";
const MAX_BYTES = 20 * 1024 * 1024;

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  const formData = await request.formData();
  const file = formData.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json({ error: "A file upload is required." }, { status: 400 });
  }
  if (file.type !== "application/pdf") {
    return NextResponse.json({ error: "Only PDF files are allowed." }, { status: 400 });
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json({ error: "Invoice PDF must be under 20MB." }, { status: 400 });
  }

  const path = `${order.id}/invoice.pdf`;

  const admin = createAdminClient();
  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(path, await file.arrayBuffer(), { contentType: file.type, upsert: true });
  if (uploadError) {
    return NextResponse.json({ error: `Upload failed: ${uploadError.message}` }, { status: 502 });
  }

  const updated = await prisma.osteqOrder.update({
    where: { id: order.id },
    data: { invoicePdfPath: path },
  });

  return NextResponse.json({ order: updated });
}

export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order || !order.invoicePdfPath) {
    return NextResponse.json({ error: "No invoice PDF on this order." }, { status: 400 });
  }

  const admin = createAdminClient();
  await admin.storage.from(BUCKET).remove([order.invoicePdfPath]);

  const updated = await prisma.osteqOrder.update({
    where: { id: order.id },
    data: { invoicePdfPath: null },
  });

  return NextResponse.json({ order: updated });
}
```

- [ ] **Step 3: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add "app/api/osteq/orders/[id]/invoice-pdf/route.ts" supabase/config.toml
git commit -m "Add invoice PDF upload/delete endpoint and private storage bucket"
```

---

### Task 7: Invoice download endpoint + hasInvoicePdf on orders JSON

**Files:**
- Create: `app/api/osteq/orders/[id]/invoice-download/route.ts`
- Modify: `lib/osteq/serialize.ts`
- Modify: `app/api/osteq/orders/route.ts`
- Modify: `app/api/osteq/orders/[id]/route.ts`

**Interfaces:**
- Consumes: `OsteqOrder.invoicePdfPath` (Task 1).
- Produces: `withInvoiceFlag(order)` helper in `lib/osteq/serialize.ts` (strips `invoicePdfPath`, adds `hasInvoicePdf: boolean`) — used by both orders routes. `GET /api/osteq/orders/[id]/invoice-download` → `{ url: string }`, consumed by Flutter Task 11.

- [ ] **Step 1: Add `withInvoiceFlag` to `lib/osteq/serialize.ts`**

Append to the end of `lib/osteq/serialize.ts`:

```typescript

/**
 * The client only ever needs to know whether an invoice PDF exists, never the raw
 * storage path (access always goes through the signed-URL endpoint) — this mirrors the
 * "store the relative path, never a URL" convention by keeping the path itself entirely
 * server-side too.
 */
export function withInvoiceFlag<T extends { invoicePdfPath?: string | null }>(
  order: T,
): Omit<T, "invoicePdfPath"> & { hasInvoicePdf: boolean } {
  const { invoicePdfPath, ...rest } = order;
  return { ...rest, hasInvoicePdf: invoicePdfPath != null };
}
```

- [ ] **Step 2: Create the download route**

Create `app/api/osteq/orders/[id]/invoice-download/route.ts`:

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order || order.customerId !== customerId || !order.invoicePdfPath) {
    return NextResponse.json({ error: "Not found." }, { status: 404 });
  }

  const admin = createAdminClient();
  const { data, error } = await admin.storage.from(BUCKET).createSignedUrl(order.invoicePdfPath, 60);
  if (error || !data) {
    return NextResponse.json({ error: "Could not generate download link." }, { status: 502 });
  }

  return NextResponse.json({ url: data.signedUrl });
}
```

- [ ] **Step 3: Apply `withInvoiceFlag` in the orders list route**

In `app/api/osteq/orders/route.ts`, add the import:

```typescript
import { serializeDecimals, withInvoiceFlag } from "@/lib/osteq/serialize";
```

(replacing the existing `import { serializeDecimals } from "@/lib/osteq/serialize";` line)

Replace the final `return` statement:

```typescript
  return NextResponse.json(serializeDecimals({ orders: orders.map(withInvoiceFlag) }));
```

- [ ] **Step 4: Apply `withInvoiceFlag` in the order detail route**

In `app/api/osteq/orders/[id]/route.ts`, add the same import change as Step 3, then replace the final `return` statement:

```typescript
  return NextResponse.json(serializeDecimals({ order: withInvoiceFlag(order) }));
```

- [ ] **Step 5: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add "app/api/osteq/orders/[id]/invoice-download/route.ts" lib/osteq/serialize.ts "app/api/osteq/orders/route.ts" "app/api/osteq/orders/[id]/route.ts"
git commit -m "Add invoice download endpoint; expose hasInvoicePdf on orders JSON"
```

---

### Task 8: Admin UI — invoice PDF upload + print page PDF link

**Files:**
- Create: `app/admin/(dashboard)/orders/[id]/InvoicePdfForm.tsx`
- Modify: `app/admin/(dashboard)/orders/[id]/page.tsx`
- Modify: `app/admin/(dashboard)/orders/[id]/invoice/page.tsx`

**Interfaces:**
- Consumes: `POST`/`DELETE /api/osteq/orders/[id]/invoice-pdf` (Task 6).

- [ ] **Step 1: Create `InvoicePdfForm.tsx`**

Create `app/admin/(dashboard)/orders/[id]/InvoicePdfForm.tsx`:

```tsx
"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

// Same direct-browser-fetch pattern as ProductImages.tsx (catalog/products/[id]) — File
// uploads need a real FormData body, which the adminApiFetch/Server Action pattern used
// elsewhere in this admin panel only ever JSON-encodes.
export function InvoicePdfForm({ orderId, hasInvoicePdf }: { orderId: string; hasInvoicePdf: boolean }) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | undefined>();

  async function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setError(undefined);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(`/api/osteq/orders/${orderId}/invoice-pdf`, { method: "POST", body: formData });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Upload failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Upload failed. Check your connection.");
    } finally {
      setBusy(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  async function handleRemove() {
    setBusy(true);
    setError(undefined);
    try {
      const res = await fetch(`/api/osteq/orders/${orderId}/invoice-pdf`, { method: "DELETE" });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Remove failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Remove failed. Check your connection.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-6">
      <h2 className="mb-2 font-medium">Invoice PDF</h2>
      <p className="mb-2 text-sm text-gray-600">
        {hasInvoicePdf ? "Invoice PDF uploaded." : "No invoice PDF uploaded yet."}
      </p>
      <input
        ref={fileInputRef}
        type="file"
        accept="application/pdf"
        onChange={handleFileChange}
        disabled={busy}
        className="text-sm"
      />
      {hasInvoicePdf && (
        <button
          type="button"
          onClick={handleRemove}
          disabled={busy}
          className="ml-2 rounded bg-red-600 px-2 py-1 text-xs text-white disabled:opacity-50"
        >
          Remove
        </button>
      )}
      {busy && <span className="ml-2 text-xs text-gray-500">Working…</span>}
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  );
}
```

- [ ] **Step 2: Wire it into the order detail page**

In `app/admin/(dashboard)/orders/[id]/page.tsx`, add the import:

```typescript
import { InvoicePdfForm } from "./InvoicePdfForm";
```

Add after the `<StatusForm order={order} />` line, before the closing `</div>`:

```tsx
      <InvoicePdfForm orderId={order.id} hasInvoicePdf={order.invoicePdfPath != null} />
```

- [ ] **Step 3: Show the uploaded PDF on the invoice print page**

Replace the full contents of `app/admin/(dashboard)/orders/[id]/invoice/page.tsx` with:

```tsx
import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import Link from "next/link";
import { PrintButton } from "./PrintButton";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";

export default async function OrderInvoicePage({ params }: { params: { id: string } }) {
  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { customer: true, items: { include: { variant: { include: { product: true } } } } },
  });
  if (!order) {
    notFound();
  }

  let uploadedInvoiceUrl: string | null = null;
  if (order.invoicePdfPath) {
    const admin = createAdminClient();
    const { data } = await admin.storage.from(BUCKET).createSignedUrl(order.invoicePdfPath, 300);
    uploadedInvoiceUrl = data?.signedUrl ?? null;
  }

  return (
    <div className="mx-auto max-w-2xl">
      <div className="mb-4 flex items-center justify-between print:hidden">
        <Link href={`/admin/orders/${order.id}`} className="text-sm underline">
          Back to order
        </Link>
        {!uploadedInvoiceUrl && <PrintButton />}
      </div>

      {uploadedInvoiceUrl ? (
        <div className="rounded border p-8 text-center">
          <p className="mb-4 text-sm text-gray-600">A staff-uploaded invoice PDF is on file for this order.</p>
          <a href={uploadedInvoiceUrl} className="underline" target="_blank" rel="noreferrer">
            View uploaded invoice PDF
          </a>
        </div>
      ) : (
        <div className="rounded border p-8 print:border-0 print:p-0">
          <h1 className="text-2xl font-bold">Osteq</h1>
          <p className="text-sm text-gray-600">AV & home-theater equipment for trade installers</p>

          <div className="mt-6 flex items-start justify-between text-sm">
            <div>
              <p className="font-medium">Invoice #{order.id.slice(0, 8).toUpperCase()}</p>
              <p>Date: {order.createdAt.toLocaleDateString()}</p>
              <p>Status: {order.status}</p>
            </div>
            <div className="text-right">
              <p>Billed to: {order.customer.email}</p>
              <p>Ship to: {order.shippingAddress}</p>
              {order.trackingNumber && <p>Tracking: {order.trackingNumber}</p>}
            </div>
          </div>

          <table className="mt-8 w-full border-collapse text-sm">
            <thead>
              <tr className="border-b text-left">
                <th className="p-2">Item</th>
                <th className="p-2">Qty</th>
                <th className="p-2">Unit ₹</th>
                <th className="p-2">Total ₹</th>
              </tr>
            </thead>
            <tbody>
              {order.items.map((item) => (
                <tr key={item.id} className="border-b">
                  <td className="p-2">
                    {item.variant.product.name} ({item.variant.sku})
                  </td>
                  <td className="p-2">{item.quantity}</td>
                  <td className="p-2">{Number(item.unitPriceInRupees).toFixed(2)}</td>
                  <td className="p-2">{(Number(item.unitPriceInRupees) * item.quantity).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p className="mt-4 text-right text-lg font-bold">
            Grand total: ₹{Number(order.totalInRupees).toFixed(2)}
          </p>

          <p className="mt-8 text-xs text-gray-500">
            This is a system-generated invoice for the above order.
          </p>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Typecheck**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add "app/admin/(dashboard)/orders/[id]/InvoicePdfForm.tsx" "app/admin/(dashboard)/orders/[id]/page.tsx" "app/admin/(dashboard)/orders/[id]/invoice/page.tsx"
git commit -m "Admin: upload/remove invoice PDF, link to it from the invoice print page"
```

---

### Task 9: Flutter dependencies — firebase_core, firebase_messaging, webview_flutter, url_launcher

**Files:**
- Modify: `customer_app/pubspec.yaml`
- Modify: `customer_app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: the four packages available for import in Tasks 10-13.

- [ ] **Step 1: Add dependencies**

In `customer_app/pubspec.yaml`, add to `dependencies:` (after `google_fonts: ^8.2.0`):

```yaml
  firebase_core: ^3.8.0
  firebase_messaging: ^15.1.5
  webview_flutter: ^4.10.0
  url_launcher: ^6.3.0
```

- [ ] **Step 2: Fetch packages**

Run (from `customer_app/`): `flutter pub get`
Expected: `Got dependencies!`. If version resolution fails, loosen the pinned versions above to whatever `flutter pub get` resolves and re-run — record the actual resolved versions in the commit.

- [ ] **Step 3: Add the Android notification permission**

In `customer_app/android/app/src/main/AndroidManifest.xml`, add after the existing `<uses-permission android:name="android.permission.INTERNET"/>` line:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 4: MANUAL STEP — iOS push capability (cannot be done by the agent)**

In Xcode, open `customer_app/ios/Runner.xcworkspace`, select the Runner target → Signing & Capabilities → "+ Capability" → add both "Push Notifications" and "Background Modes" (check "Remote notifications" under it). This is required for `firebase_messaging` to receive pushes on iOS at all; note it in the final verification task if not done yet — Android and the rest of this plan work without it.

- [ ] **Step 5: Analyze**

Run (from `customer_app/`): `flutter analyze`
Expected: no new errors (unused-import warnings are fine at this point — the packages aren't used yet).

- [ ] **Step 6: Commit**

```bash
git add customer_app/pubspec.yaml customer_app/pubspec.lock customer_app/android/app/src/main/AndroidManifest.xml
git commit -m "Add firebase_core, firebase_messaging, webview_flutter, url_launcher"
```

---

### Task 10: Flutter — push registration + notification tap deep link

**Files:**
- Create: `customer_app/lib/core/push_service.dart`
- Create: `customer_app/lib/core/push_provider.dart`
- Modify: `customer_app/lib/main.dart`
- Modify: `customer_app/lib/features/shell/app_shell.dart`

**Interfaces:**
- Consumes: `apiClientProvider` (`lib/core/api_client.dart`), `currentSessionProvider` (`lib/features/auth/auth_provider.dart`), `rootNavigatorKey` (`lib/core/navigator_key.dart`).
- Produces: `setupNotificationTapHandling()` and `registerDeviceToken(Dio)` (`push_service.dart`), `pushRegistrationProvider` (`push_provider.dart`) — watched by `AppShell`.

- [ ] **Step 1: Create `push_service.dart`**

Create `customer_app/lib/core/push_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'navigator_key.dart';

bool _tapHandlersRegistered = false;

/// Registers handlers that react to a push notification being tapped, both while the app
/// is backgrounded (onMessageOpenedApp) and the cold-start case where the tap launched the
/// app (getInitialMessage). Called once from main() — navigation doesn't require an
/// authenticated session to be wired up, only the destination screen's own API calls do.
void setupNotificationTapHandling() {
  if (_tapHandlersRegistered) return;
  _tapHandlersRegistered = true;

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _handleMessageTap(message);
  });
}

void _handleMessageTap(RemoteMessage message) {
  final orderId = message.data['orderId'];
  if (orderId is! String || orderId.isEmpty) return;
  final context = rootNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    GoRouter.of(context).pushNamed('orderDetail', pathParameters: {'id': orderId});
  }
}

bool _refreshListenerRegistered = false;

/// Requests notification permission, registers the current FCM token with the backend,
/// and (once) subscribes to token-refresh so a renewed token gets re-registered too.
/// A no-op if Firebase was never initialized (main.dart skips init when the
/// --dart-define Firebase values aren't configured yet).
Future<void> registerDeviceToken(Dio dio) async {
  if (Firebase.apps.isEmpty) return;

  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await _postToken(dio, token);
  }

  if (!_refreshListenerRegistered) {
    _refreshListenerRegistered = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) => _postToken(dio, newToken));
  }
}

Future<void> _postToken(Dio dio, String token) async {
  try {
    await dio.post('/api/osteq/customers/device-token', data: {'fcmToken': token});
  } on DioException {
    // Best-effort — a failed device-token registration shouldn't block app usage, only
    // means this device won't receive push until the next successful registration
    // attempt (e.g. next login or token refresh).
  }
}
```

- [ ] **Step 2: Create `push_provider.dart`**

Create `customer_app/lib/core/push_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_provider.dart';
import 'api_client.dart';
import 'push_service.dart';

/// Mirrors customerProfileProvider's pattern: registers this device's FCM token with the
/// backend whenever a Supabase session exists, and is a no-op otherwise (e.g. logged out).
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return;
  final dio = ref.watch(apiClientProvider).dio;
  await registerDeviceToken(dio);
});
```

- [ ] **Step 3: Initialize Firebase and tap handling in `main.dart`**

Replace the full contents of `customer_app/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/push_service.dart';
import 'theme/app_theme.dart';

const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  // Skipped when unconfigured (fresh checkout, no Firebase project set up yet) — the rest
  // of the app works fine without it, push just stays inert until these are provided.
  if (firebaseApiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
      ),
    );
    setupNotificationTapHandling();
  }
  runApp(const ProviderScope(child: OsteqApp()));
}

class OsteqApp extends StatelessWidget {
  const OsteqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Osteq',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 4: Watch `pushRegistrationProvider` in `AppShell`**

In `customer_app/lib/features/shell/app_shell.dart`, add the import:

```dart
import '../../core/push_provider.dart';
```

Add after `ref.watch(customerProfileProvider);`:

```dart
    ref.watch(pushRegistrationProvider);
```

- [ ] **Step 5: Analyze**

Run (from `customer_app/`): `flutter analyze`
Expected: no errors.

- [ ] **Step 6: MANUAL STEP — create the Firebase project (cannot be done by the agent)**

Go to the Firebase console (console.firebase.google.com), create a project (messaging only — no other Firebase product needed), add an app for each platform used (Android package `com.osteq.customer_app`, iOS bundle id matching `customer_app/ios/Runner.xcodeproj`), and from Project settings → General, collect the Web API Key, App ID, Sender ID, and Project ID needed for the `--dart-define` values above. Also generate a service account key (Project settings → Service accounts) for `FIREBASE_SERVICE_ACCOUNT_JSON` from Task 4. Run the app with:

```bash
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=... --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

- [ ] **Step 7: Commit**

```bash
git add customer_app/lib/core/push_service.dart customer_app/lib/core/push_provider.dart customer_app/lib/main.dart customer_app/lib/features/shell/app_shell.dart
git commit -m "Flutter: register FCM device token, deep-link into order on notification tap"
```

---

### Task 11: Flutter — order model fields + invoice download repository method

**Files:**
- Modify: `customer_app/lib/features/orders/order_model.dart`
- Modify: `customer_app/lib/features/orders/orders_repository.dart`

**Interfaces:**
- Consumes: `hasInvoicePdf`/`trackingUrl` fields on order JSON (Task 7/Task 2), `GET /api/osteq/orders/[id]/invoice-download` (Task 7).
- Produces: `Order.trackingUrl: String?`, `Order.hasInvoicePdf: bool`, `OrdersRepository.fetchInvoiceDownloadUrl(String orderId): Future<String>` — consumed by Tasks 12-13.

- [ ] **Step 1: Update `order_model.dart`**

Replace the `Order` class (from `class Order {` to the end of the file) with:

```dart
class Order {
  final String id;
  final String status;
  final String shippingAddress;
  final String? trackingNumber;
  final String? trackingUrl;
  final bool hasInvoicePdf;
  final double totalInRupees;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? customerEmail;

  Order({
    required this.id,
    required this.status,
    required this.shippingAddress,
    this.trackingNumber,
    this.trackingUrl,
    required this.hasInvoicePdf,
    required this.totalInRupees,
    required this.createdAt,
    required this.items,
    this.customerEmail,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      shippingAddress: json['shippingAddress'] as String,
      trackingNumber: json['trackingNumber'] as String?,
      trackingUrl: json['trackingUrl'] as String?,
      hasInvoicePdf: json['hasInvoicePdf'] as bool? ?? false,
      totalInRupees: (json['totalInRupees'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      customerEmail: customer?['email'] as String?,
    );
  }
}
```

- [ ] **Step 2: Add `fetchInvoiceDownloadUrl` to `orders_repository.dart`**

In `customer_app/lib/features/orders/orders_repository.dart`, add this method to the `OrdersRepository` class (after `fetchOne`):

```dart
  Future<String> fetchInvoiceDownloadUrl(String orderId) async {
    try {
      final res = await _dio.get('/api/osteq/orders/$orderId/invoice-download');
      return res.data['url'] as String;
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
```

- [ ] **Step 3: Analyze**

Run (from `customer_app/`): `flutter analyze`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add customer_app/lib/features/orders/order_model.dart customer_app/lib/features/orders/orders_repository.dart
git commit -m "Flutter: add trackingUrl/hasInvoicePdf to Order, invoice download repository method"
```

---

### Task 12: Flutter — tracking WebView screen + order detail button

**Files:**
- Create: `customer_app/lib/features/orders/tracking_webview_screen.dart`
- Modify: `customer_app/lib/core/router.dart`
- Modify: `customer_app/lib/features/orders/order_detail_screen.dart`

**Interfaces:**
- Consumes: `Order.status`, `Order.trackingUrl` (Task 11).
- Produces: go_router route `orderTracking` (path `orders/:id/tracking`, expects `extra: String` = the URL).

- [ ] **Step 1: Create `tracking_webview_screen.dart`**

Create `customer_app/lib/features/orders/tracking_webview_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrackingWebViewScreen extends StatefulWidget {
  const TrackingWebViewScreen({super.key, required this.url});

  final String url;

  @override
  State<TrackingWebViewScreen> createState() => _TrackingWebViewScreenState();
}

class _TrackingWebViewScreenState extends State<TrackingWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

- [ ] **Step 2: Register the route**

In `customer_app/lib/core/router.dart`, add the import (after `import '../features/orders/invoice_screen.dart';`):

```dart
import '../features/orders/tracking_webview_screen.dart';
```

In the `orderDetail` `GoRoute`'s nested `routes:` list, add after the `orderInvoice` route:

```dart
                  GoRoute(
                    path: 'tracking',
                    name: 'orderTracking',
                    builder: (context, state) => TrackingWebViewScreen(url: state.extra as String),
                  ),
```

- [ ] **Step 3: Add the "Track live location" button to `order_detail_screen.dart`**

In `customer_app/lib/features/orders/order_detail_screen.dart`, add after the existing `if (order.trackingNumber != null) Text('Tracking: ${order.trackingNumber}'),` line:

```dart
            if (order.status == 'OUT_FOR_DELIVERY' && order.trackingUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () => context.pushNamed(
                    'orderTracking',
                    pathParameters: {'id': orderId},
                    extra: order.trackingUrl,
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Track live location'),
                ),
              ),
```

- [ ] **Step 4: Analyze**

Run (from `customer_app/`): `flutter analyze`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add customer_app/lib/features/orders/tracking_webview_screen.dart customer_app/lib/core/router.dart customer_app/lib/features/orders/order_detail_screen.dart
git commit -m "Flutter: in-app WebView for live delivery tracking"
```

---

### Task 13: Flutter — invoice PDF download button

**Files:**
- Modify: `customer_app/lib/features/orders/invoice_screen.dart`

**Interfaces:**
- Consumes: `Order.hasInvoicePdf` (Task 11), `OrdersRepository.fetchInvoiceDownloadUrl` (Task 11), `ordersRepositoryProvider` (`orders_repository.dart`), `ApiException` (`core/api_exception.dart`).

- [ ] **Step 1: Replace `invoice_screen.dart`**

Replace the full contents of `customer_app/lib/features/orders/invoice_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_exception.dart';
import 'order_model.dart';
import 'orders_provider.dart';
import 'orders_repository.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: orderAsync.when(
        data: (order) =>
            order.hasInvoicePdf ? _InvoicePdfDownload(orderId: orderId) : _InvoiceBody(order: order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load invoice: $error')),
      ),
    );
  }
}

class _InvoicePdfDownload extends ConsumerStatefulWidget {
  const _InvoicePdfDownload({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_InvoicePdfDownload> createState() => _InvoicePdfDownloadState();
}

class _InvoicePdfDownloadState extends ConsumerState<_InvoicePdfDownload> {
  bool _loading = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref.read(ordersRepositoryProvider).fetchInvoiceDownloadUrl(widget.orderId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 48),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _download,
            icon: _loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: const Text('Download invoice PDF'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Osteq', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const Text('AV & home-theater equipment for trade installers'),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice #${order.id.substring(0, 8).toUpperCase()}', style: textTheme.titleMedium),
                Text('Date: ${order.createdAt.toLocal().toString().substring(0, 10)}'),
                Text('Status: ${order.status}'),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (order.customerEmail != null) Text('Billed to: ${order.customerEmail}'),
                Text('Ship to: ${order.shippingAddress}', textAlign: TextAlign.right),
                if (order.trackingNumber != null) Text('Tracking: ${order.trackingNumber}'),
              ],
            ),
          ],
        ),
        const Divider(height: 32),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
          },
          border: TableBorder(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          children: [
            TableRow(
              children: [
                _cell('Item', bold: true),
                _cell('Qty', bold: true),
                _cell('Unit ₹', bold: true),
                _cell('Total ₹', bold: true),
              ],
            ),
            ...order.items.map(
              (item) => TableRow(
                children: [
                  _cell(item.productName ?? item.sku ?? item.variantId.substring(0, 8)),
                  _cell('${item.quantity}'),
                  _cell(item.unitPriceInRupees.toStringAsFixed(2)),
                  _cell(item.lineTotalInRupees.toStringAsFixed(2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Grand total: ₹${order.totalInRupees.toStringAsFixed(2)}',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'This is a system-generated invoice for the above order.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run (from `customer_app/`): `flutter analyze`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add customer_app/lib/features/orders/invoice_screen.dart
git commit -m "Flutter: download uploaded invoice PDF instead of rendering one when present"
```

---

### Task 14: End-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Apply the migration on the VPS**

This worktree has no DB connection — on the VPS (or wherever `DATABASE_URL` points to the real self-hosted Postgres), run `npx prisma migrate deploy` (or apply `prisma/migrations/20260922120000_add_tracking_push_invoice/migration.sql` directly via `psql`) before deploying this branch.

- [ ] **Step 2: Create the `order-invoices` bucket**

If not already done in Task 6's manual step: in the production Supabase Studio, Storage → New bucket → `order-invoices` → Public **OFF** → 20MB limit → `application/pdf` only.

- [ ] **Step 3: Configure `FIREBASE_SERVICE_ACCOUNT_JSON` on the VPS deployment**

Add the service account JSON (from Task 10's manual Firebase project step) to the running `osteq-app` container's environment (`.env` used by `docker-compose.yml` or wherever `RESEND_API_KEY` is currently set).

- [ ] **Step 4: Manual tracking flow check**

As staff: open an order in `/admin/orders/[id]`, paste a Rapido/Porter link into the tracking field, submit. Confirm the order's status flips to `OUT_FOR_DELIVERY` without picking it from the dropdown. As the customer in the Flutter app: open that order, confirm "Track live location" appears and opens the link inside an in-app WebView (not an external browser).

- [ ] **Step 5: Manual push check**

With the customer app installed, logged in, and Firebase configured per Task 10's manual step: repeat Step 4's tracking-link submission on a different order. Confirm a push notification arrives on the device, and tapping it opens that order's detail screen (both from background and from a cold start / app fully closed).

- [ ] **Step 6: Manual invoice PDF check**

As staff: upload a PDF via the order detail page's Invoice PDF section. Confirm `/admin/orders/[id]/invoice` now shows "View uploaded invoice PDF" instead of the rendered HTML invoice. As the customer: open that order's invoice screen, confirm it shows "Download invoice PDF" instead of the rendered invoice, and tapping it opens the PDF. As staff: click "Remove" and confirm both views revert to the rendered invoice.

- [ ] **Step 7: Final full-repo check**

Run: `DATABASE_URL="postgresql://user:pass@localhost:5432/db" DIRECT_URL="postgresql://user:pass@localhost:5432/db" npx tsc --noEmit && cd customer_app && flutter analyze`
Expected: no errors from either command.
