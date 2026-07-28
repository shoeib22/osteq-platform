# Osteq Customer App (Flutter)

## Context

This is the second of three Osteq sub-projects (backend API, this customer-facing app,
and an admin panel). The backend API (`app/api/osteq/*` in this repo) is already built,
reviewed, and build-verified — this app is the first real consumer of it. Full runtime
verification of the backend against a live database is still pending (see the repo's
README and the migration history from `qube-technologies-platform`), so this app's own
manual verification (Section "Testing approach") is the first time these endpoints will
actually be exercised end-to-end.

Per the user's decision, this spec covers the full v1 feature set in one pass rather than
phasing catalog-browsing-only first: catalog browsing, trade account application, cart and
checkout, and the quote/RFQ lifecycle.

## Scope

**In scope (v1):**
- Public catalog browsing (categories, products, variants) with retail pricing shown to
  anonymous/unapproved users and trade pricing shown to trade-approved customers.
- Email/password signup and login via Supabase Auth, matching the backend's expected
  bearer-token auth.
- Trade account application submission and status display (pending/approved/rejected).
- Cart: add/update/remove items, view running total.
- Checkout: shipping address, place order (against the backend's stub payment provider —
  no real payment UI yet, matching the backend's own deferred payment integration).
- Order history and order detail.
- Quote/RFQ builder: add catalog items and/or custom line items, submit; view quote status,
  staff-set pricing, revision-request thread; accept (converts to an order) or reject.
- iOS, Android, and Web targets from one Flutter codebase.

**Explicitly out of scope (later phases):**
- The admin panel (separate sub-project — this app never authenticates as staff).
- Real payment processing (no processor selected on the backend yet).
- Offline support / local persistence beyond what Supabase's session handling provides —
  every screen refetches from the API live.
- Push notifications (the backend sends email only for v1).

## Architecture

- **Location:** `osteq-platform/customer_app` — a subdirectory of the same repo as the
  backend, following the pattern already established by `technician_app` living inside
  `qube-technologies-platform`.
- **Stack:** `flutter_riverpod` (state management), `dio` (HTTP client), `supabase_flutter`
  (auth), `go_router` (navigation) — the first three match `technician_app`'s existing
  conventions exactly; `go_router` is new to this codebase but a deliberate choice given
  this app has more screens and needs a clean deep-link story for the Web target, which
  `technician_app`'s simpler imperative `Navigator` never needed.
- **Folder structure:** mirrors `technician_app` — `lib/core/` (API client, Supabase
  client), `lib/features/<feature>/` (one folder per feature: `catalog/`, `cart/`,
  `checkout/`, `orders/`, `quotes/`, `trade/`, `account/`, `auth/`), each containing its
  repository, models, and screens; `lib/theme/`; `lib/widgets/` for cross-feature shared
  components (e.g. a price-display widget that switches retail/trade based on account
  status).
- **Auth model:** the `dio` client's request interceptor attaches the current Supabase
  session's access token as `Authorization: Bearer <token>` on every request, matching
  what `lib/osteq/auth.ts`'s `requireOsteqCustomerAccess` expects on the backend. No
  separate token management — `supabase_flutter` owns the session lifecycle.
- **No offline persistence:** every screen fetches fresh from the API; the only local
  state is what Riverpod holds in memory for the current session plus whatever
  `supabase_flutter` persists for auth (its own secure storage, not something this app
  manages directly).

## Screens & navigation

A bottom-navigation shell (`go_router`'s `StatefulShellRoute`) with four tabs — **Catalog**,
**Cart**, **Quotes**, **Account** — each preserving its own navigation stack when switching
tabs. Full screen list:

- **Catalog tab:** category list → product list (search/filter by category; each product
  card shows the price returned by the backend, which is already resolved to retail or
  trade — the app never re-derives pricing itself) → product detail (variant picker showing
  attributes like length/size, add-to-cart button).
- **Cart tab:** cart view (line items, quantities, running total) → checkout (shipping
  address form, place order) → order confirmation → order history list → order detail.
  Order history/detail is also reachable from the Account tab.
- **Quotes tab:** quotes list (status badges: submitted/under review/quoted/revision
  requested/accepted/rejected/converted) → new quote builder (add catalog items via a
  product picker and/or free-text custom line items, submit) → quote detail (line items
  with staff-set pricing once quoted, a message thread for revision requests, accept/reject
  actions once quoted — accept requires a shipping address, mirroring the backend's
  requirement).
- **Account tab:** profile view (business name/type/phone, trade account status), a trade
  application form (shown when status is not yet approved, replaced by a status badge once
  submitted), order history shortcut, logout.
- **Auth screens** (login, signup) are not tabs — they're presented as a full-screen route
  pushed on top of whatever the user was doing, triggered the first time an unauthenticated
  action is attempted (add to cart, submit a quote, apply for trade, or open Account), per
  the "browse first, log in at checkout" decision. Successful auth pops back to where the
  user was.

## Data flow & state management

Each feature owns a `Repository` class (e.g. `CatalogRepository`, `CartRepository`,
`QuotesRepository`) that wraps calls to the matching `/api/osteq/*` endpoints via the
shared `dio` client — the same shape as `technician_app`'s `*_repository.dart` files.
Riverpod providers expose repository state to widgets:

- `authProvider` — wraps the Supabase session and the derived `OsteqCustomerProfile`
  (including `accountStatus`), the single source of truth for whether trade pricing/actions
  are available. Every screen that needs to know "is this user trade-approved" reads this
  provider rather than re-deriving it.
- `catalogProvider` — categories and products, parameterized by the active category/search
  filter, refetched on filter change.
- `cartProvider` — mirrors `/api/osteq/cart` server state; add/update/remove call the
  repository then refetch the cart (no client-side-only optimistic total calculation, to
  avoid drifting from the server's price resolution).
- `quotesProvider` — quotes list and quote detail, refetched after any mutating action
  (submit, respond, message).

No local database or cache layer — every provider's data comes from a live API call, per
the online-only decision. A pull-to-refresh gesture on list screens re-invokes the
underlying repository call.

## Error handling

The shared `dio` client has a response interceptor that maps any non-2xx response into a
typed `ApiException { statusCode, message }`, reading the `message` from the backend's
consistent `{ error: string }` JSON shape (every Osteq API route already returns this
shape, per the backend spec). Screens surface `ApiException.message` directly in a
`SnackBar` or inline error banner — many of these messages are already meant for a human
reader (e.g. "Insufficient stock for SKU ...", "Every line item must be priced before
accepting.", "Quote status changed, please retry."), so no separate error-copy layer is
needed. A 401 specifically triggers the login screen rather than a generic error banner,
treated as "your session expired," not a normal request failure. Network-level failures
(no connectivity, timeout) show a retry button rather than failing silently.

## Testing approach

Flutter's built-in `flutter_test` — matching `technician_app`'s existing
`test/*_test.dart` pattern, so no new test tooling is introduced:

- Model tests: JSON → Dart model parsing round-trips for each feature's data models
  (product/variant, cart item, quote, order), since these are the most likely place a
  backend field-naming mismatch would silently break the app.
- Repository tests: each repository's methods against a mocked `dio` adapter, verifying
  the request shape (headers, body) and response parsing — not hitting the real network.
- Key widget tests: the price-display widget correctly shows retail vs. trade pricing
  based on account status; the quote-detail screen correctly disables "Accept" until every
  line item has a `quotedUnitPriceInPaise`.
- Manual verification: `flutter run` against a connected Android device (the user's OnePlus)
  for the two golden paths — browse catalog → add to cart → checkout, and browse catalog →
  build a quote → submit — once the backend's live database is available to test against
  (per the still-pending backend E2E verification noted in Context above). Until then,
  manual verification runs against a local/mocked backend response set so the UI itself can
  be validated independently of the backend's live-DB blocker.
