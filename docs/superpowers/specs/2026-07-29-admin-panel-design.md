# Osteq Admin Panel

## Context

This is the third and final Osteq sub-project (backend and customer app both already built,
reviewed, and live-verified on a physical device). Staff currently have API access to every
admin action (trade approval, catalog management, quote pricing, order status) but no UI —
someone would have to script curl calls to run the business. This spec covers a Next.js web
dashboard that gives staff a real interface for all of it.

This is a genuinely separate, independent admin panel from Qube Technologies' own internal
admin dashboard in `qube-technologies-platform` — different repo, different database,
different staff auth model (Osteq's own `Staff` table, not Qube's `Profile`/`Role`), different
deployment. The two share no code or data; they only share a UI/architecture *convention*
(Server Components + Server Actions) that has worked well in the Qube dashboard.

## Scope

**In scope (v1):**
- Staff login page (`/admin/login`) — email/password via Supabase Auth, matching the
  `Staff` model's existing mirroring pattern.
- Trade application review: list (filterable by status), approve/reject with a rejection
  reason.
- Catalog management: create/edit categories, create/edit products, create/edit variants
  (price, stock, attributes) — including three backend routes this spec adds as prerequisites
  (see below), since editing a variant's price/stock or a category's name currently has no
  API surface at all.
- Quote management: list all quotes (filterable by status), quote detail with line-item
  pricing input, message thread (staff can post messages/revision responses).
- Order management: list all orders (filterable by status), order detail with status/tracking
  number updates — also needs a new prerequisite backend route, since staff currently have no
  way to list orders at all (the existing `GET /api/osteq/orders` is customer-scoped only).

**Explicitly out of scope (later):**
- Staff account creation UI — stays a manual process (create the Supabase Auth user, insert
  the matching `Staff` row), per this repo's README and matching how Qube's own first-admin
  provisioning works. Not worth building a UI for something that happens rarely and
  deliberately isn't self-serve.
- Analytics/reporting dashboards, bulk catalog import, category deletion (only create/edit).
- Any visual/branding polish — the whole app (customer app included) is getting a design pass
  later; this spec's screens use plain, functional styling only.

## Prerequisite backend additions

Three gaps found while reviewing the existing API surface against what this panel needs:

1. `PATCH /api/osteq/categories/[id]` — edit `name`/`slug`/`parentCategoryId`. Doesn't exist;
   only creation (`POST /api/osteq/categories`) exists today.
2. `PATCH /api/osteq/products/[id]/variants/[variantId]` — edit `sku`/`attributes`/
   `retailPriceInPaise`/`tradePriceInPaise`/`stockQuantity`/`isActive`. Doesn't exist; a
   variant's price/stock currently can never change after creation via the API.
3. `GET /api/osteq/orders` (staff variant) and `GET /api/osteq/orders/[id]` (staff bypass) —
   the existing routes only return the *authenticated customer's own* orders
   (`where: { customerId }`). Staff need to see every order. Mirrors the exact
   dual-auth pattern already used by `GET /api/osteq/quotes` (staff sees all, customer sees
   own) — reuse that pattern, don't invent a new one.

## Architecture

- New `app/admin/*` routes in this same repo. `app/admin/(dashboard)/layout.tsx` wraps every
  page below it: calls `requireStaffAccess()` (already built, cookie-session based) to gate
  access, renders a simple nav (Trade Applications / Catalog / Quotes / Orders / Logout).
  `middleware.ts` already redirects unauthenticated `/admin/*` requests to `/admin/login` —
  that login page doesn't exist yet and is part of this build.
- **Reads** (list/detail pages) are Server Components querying Prisma directly — matches
  Qube's own dashboard convention, and there's no reason to round-trip through the API layer
  for a read that has no business logic beyond a `findMany`/`findUnique`.
- **Mutations** go through the existing, already-reviewed API routes: each admin section gets
  an `actions.ts` file (`"use server"`) whose functions `fetch()` the corresponding
  `/api/osteq/*` route (absolute URL built from the incoming request's host) with the staff
  session cookie forwarded via `next/headers`. This is a deliberate deviation from Qube's
  "Server Actions hit Prisma directly" convention: several of these routes contain
  hard-won race-condition guards (conditional `updateMany`s keyed on expected prior state,
  transactions) that were found and fixed during the backend's own build — reusing them via
  fetch means zero risk of the admin panel silently reintroducing one of those bugs by
  duplicating the logic in a second place.

## Screens

- **`/admin/login`** — email/password form, calls Supabase Auth directly (client-side, same
  as any Supabase Auth login), redirects to `/admin` on success.
- **`/admin/trade-applications`** — table of applications (business name/type/phone/customer
  email/status/submitted date), status filter. Each pending row has Approve/Reject buttons;
  Reject opens a reason field. Calls the existing `PATCH /api/osteq/trade-applications/[id]`.
- **`/admin/catalog`** — category list with an inline "add category" form and an edit action
  per row (uses the new `PATCH /categories/[id]`). Each category links to
  **`/admin/catalog/[categoryId]`** — that category's products, with an "add product" form.
  Each product links to **`/admin/catalog/products/[id]`** — product detail: editable
  fields (name/description/specs/images/isActive) via the existing
  `PATCH /api/osteq/products/[id]`, plus a variants table (sku/attributes/prices/stock) with
  inline edit (new `PATCH /variants/[variantId]`) and an "add variant" form (existing
  `POST /variants`).
- **`/admin/quotes`** — table of all quotes (customer/status/created date), status filter.
  Each row links to **`/admin/quotes/[id]`** — line items with a price-entry field per
  unpriced item (existing `PATCH /api/osteq/quotes/[id]/price`), the full message thread with
  a reply box (existing `POST /messages`), and the quote's current status.
- **`/admin/orders`** — table of all orders (customer/status/total/created date, using the new
  staff `GET /orders`), status filter. Each row links to **`/admin/orders/[id]`** — line
  items, shipping address, and a status/tracking-number update form (existing
  `PATCH /api/osteq/orders/[id]/status`).

## Data flow & mutations

Each section's `actions.ts` exports one `"use server"` function per mutation
(`approveTradeApplication`, `updateVariant`, `priceQuoteItems`, `updateOrderStatus`, etc.).
Each function: reads the incoming request's cookies via `next/headers`, `fetch()`s the target
API route with those cookies forwarded and the request body as JSON, and returns
`{ error?: string }` parsed from the API's own `{ error: string }` response shape on failure,
or triggers a Next.js `revalidatePath`/redirect on success so the calling page reflects the
new state immediately.

## Error handling & testing

Every mutation form uses React's `useActionState` (a client component wrapping the server
action) to display `error` inline next to the form, without a full page reload — the message
shown is always the backend's own message (e.g. "You already have a pending trade
application.", "Quote status changed, please retry.") rather than a generic wrapper, matching
how the customer app surfaces `ApiException.message` verbatim.

No test runner exists in this repo (same as the backend and customer app) — verification is
manual: click through every screen in a browser against the local Supabase instance +
`npm run dev` + the seeded test product and staff account already set up from the customer
app's device-testing session. Since this is a desktop web dashboard (not a mobile app), no
device/tunnel setup is needed for this verification — just a browser pointed at
`localhost:3000/admin`.
