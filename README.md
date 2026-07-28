# Osteq Platform

Backend API for Osteq, a B2B e-commerce app for AV/home-theater equipment (cables, mounts,
projector screens, speakers) sold to trade installers/integrators. Migrated out of the
`qube-technologies-platform` monorepo, where it was originally built as a client sub-project,
into its own repo with its own Supabase project and its own staff/admin model.

## Stack

- Next.js 14 (App Router) + TypeScript
- Tailwind CSS
- Supabase: Postgres (via Prisma), Auth, Storage
- Deployed on Vercel (once configured)

## Setup

```bash
npm install
cp .env.example .env.local
# Fill in .env.local with your Supabase project's credentials
# (Project Settings -> API, and Project Settings -> Database for the connection strings).
```

Apply the schema to your Supabase Postgres instance:

```bash
npx prisma migrate dev
```

### Creating the first staff account

Supabase Auth owns `auth.users`; this app's `staff` table (Prisma) mirrors it with the
app-specific `role` field. To create your first staff/admin user:

1. Add a user in the Supabase dashboard (Authentication -> Users -> Add user).
2. Insert a matching row into `staff` with that user's `id` — there's no self-serve
   "become staff" flow by design; the first staff account is provisioned by hand.

## What's here

- `app/api/osteq/*` — the full backend API: customer auth/profile, trade account
  application + approval, product catalog (categories/products/variants) with two-tier
  (retail/trade) pricing, cart, checkout, the quote/RFQ lifecycle, order status, and
  best-effort email notifications.
- `lib/osteq/*` — shared logic: customer bearer-token auth, pricing resolution, the quote
  status-transition guard, the payment-provider interface (currently a stub — no real
  processor wired in yet), and the notification helper.
- `lib/auth.ts` — staff session auth (`requireStaffAccess()`), gates every admin-facing
  route (trade approval, catalog management, quote pricing, order status updates).
- `prisma/schema.prisma` — all models are `Osteq*`-prefixed, a holdover from when this
  code shared a database with an unrelated internal CRM in the monorepo it came from;
  kept as-is here rather than renamed, since it's cosmetic and the rename would touch
  every route file for no functional benefit.

## Not yet built

- The customer-facing Flutter app (iOS/Android/Web) that will consume this API.
- The admin panel UI (this repo currently only exposes the API surface the admin panel
  will call — trade approval, quote pricing, catalog CRUD, order status — with no
  dashboard pages yet).
- A real payment processor (Stripe/PayPal) — checkout is built against a
  `PaymentProvider` interface with a stub implementation that always succeeds.
