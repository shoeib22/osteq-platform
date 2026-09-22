# Live delivery tracking (Rapido/Porter link) + out-for-delivery push notification

## Problem

Osteq orders are last-mile delivered locally via Rapido/Porter. Staff currently have no way
to share the courier's live tracking link with the customer, and customers get no signal
that a courier has actually been dispatched — only a generic "order status changed" email.

## Goals

- Staff can attach a Rapido/Porter tracking link to an order.
- Customers can view that link's live tracking *inside* the app (an embedded viewport,
  not a browser hand-off).
- Customers get a real push notification the moment the order goes out for delivery.

## Non-goals

- Multi-device push (one `fcmToken` per customer, latest wins).
- Parsing/validating that a URL actually belongs to Rapido or Porter — any URL is accepted.
- A generic notification system for other events (this wires push into the existing
  status-change path only, for the `OUT_FOR_DELIVERY` transition).

## Data model (`prisma/schema.prisma`)

- `OsteqOrder.trackingUrl String?` — new column, the Rapido/Porter share link.
- `OsteqOrderStatus` enum: rename `SHIPPED` → `OUT_FOR_DELIVERY`. Existing rows keep their
  status value, just relabeled — no backfill needed since Prisma enum renames are a rename
  of the underlying Postgres enum label.
- `OsteqCustomerProfile.fcmToken String?` — new column, latest FCM device token.

## Backend (`app/api/osteq/**`, `lib/osteq/**`)

### `PATCH /api/osteq/orders/[id]/status`

- Accepts an optional `trackingUrl` string in the body (same null/empty-string-means-clear
  convention already used for `trackingNumber`).
- If `trackingUrl` is being set for the first time on this request (existing order had
  `trackingUrl == null`, request supplies a non-null value) and the order's current status
  is not `DELIVERED` or `CANCELLED`, the handler overrides whatever `status` was submitted
  and forces `status = OUT_FOR_DELIVERY`. This is the "auto trigger" behavior — pasting the
  link is what actually marks the order out for delivery.
- Basic validation: `trackingUrl`, if non-null, must be a syntactically valid URL
  (`new URL(...)` in a try/catch) — reject with 400 otherwise.

### `POST /api/osteq/customers/device-token`

- New route, same `requireOsteqCustomerAccess` auth pattern as `customers/me/route.ts`.
- Body: `{ fcmToken: string }`. Upserts `fcmToken` onto the caller's `OsteqCustomerProfile`
  (create-if-missing is not needed here — device-token registration only ever happens after
  the profile exists, i.e. post-login).
- Returns `{ ok: true }`.

### `lib/osteq/notifications.ts`

- Add `sendPush(fcmToken: string, title: string, body: string, data: Record<string,string>)`
  using the `firebase-admin` SDK. Service account credentials come from an env var
  (`FIREBASE_SERVICE_ACCOUNT_JSON`, parsed once at module load). Mirrors the existing
  `sendEmail` fire-and-forget contract: catches and logs, never throws.
- `notifyOrderStatusChange(order)`: keep the existing email send for every status change.
  Additionally, when `order.status === "OUT_FOR_DELIVERY"`, look up the customer's
  `fcmToken`; if present, call `sendPush` with a title/body referencing the order and
  `data: { orderId: order.id, trackingUrl: order.trackingUrl ?? "" }` for client-side
  deep-linking. If no `fcmToken` is on file, skip silently (no error, no email substitute —
  the email already went out above).

## Admin UI (`app/admin/(dashboard)/orders/[id]/StatusForm.tsx`, `actions.ts`)

- Status `<select>` options: replace `"SHIPPED"` with `"OUT_FOR_DELIVERY"`.
- Add a second text input for `trackingUrl` next to the existing `trackingNumber` input,
  same styling, same clear-on-empty-string convention.
- `actions.ts`'s `updateOrderStatus` passes `trackingUrl` through to the PATCH body
  alongside `trackingNumber`.

## Flutter customer app (`customer_app/`)

### Dependencies

- `firebase_core`, `firebase_messaging` — push.
- `webview_flutter` — in-app tracking viewport.
- Requires creating a Firebase project (free tier, messaging only) and adding
  `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) to the app. Firebase
  is used purely as the push delivery pipe; the trigger stays on the existing VPS backend
  via `firebase-admin`.

### Push registration

- `main.dart`: initialize Firebase alongside the existing `initSupabase()` call.
- After a session exists (post-login, and on app resume if a session is already present):
  request notification permission (`FirebaseMessaging.instance.requestPermission()`), read
  the current token (`getToken()`), POST it to `/api/osteq/customers/device-token` via the
  existing `OsteqApiClient`.
- Subscribe to `FirebaseMessaging.instance.onTokenRefresh` and re-POST on change.

### Notification tap → deep link

- Register `FirebaseMessaging.onMessageOpenedApp` and the cold-start
  `getInitialMessage()` path. Both extract `orderId` from the message's `data` payload and
  use `rootNavigatorKey.currentContext` + `GoRouter` to push the order detail route for
  that order — same navigation pattern already used for the 401 redirect in
  `api_client.dart`.
- Foreground messages: no local-notification popup is added in this pass (out of scope);
  the order detail screen will simply reflect the new status/tracking link next time it's
  viewed or refreshed.

### Order model & screens

- `order_model.dart`: add `final String? trackingUrl;`, parsed from JSON like
  `trackingNumber`.
- `order_detail_screen.dart`: when `order.status == 'OUT_FOR_DELIVERY' && order.trackingUrl
  != null`, show a "Track live location" button that pushes a new route to
  `TrackingWebViewScreen(url: order.trackingUrl!)`.
- New `lib/features/orders/tracking_webview_screen.dart`: a `Scaffold` with an `AppBar`
  ("Live tracking") and a `WebViewWidget` that loads `trackingUrl` directly via
  `WebViewController().loadRequest(Uri.parse(url))` — renders exactly what the link shows
  in a browser, embedded in-app.

## Error handling

- Invalid `trackingUrl` on the status PATCH → 400, admin form shows the existing inline
  error pattern already used by `StatusForm`.
- Missing/unconfigured `FIREBASE_SERVICE_ACCOUNT_JSON` → `sendPush` logs and no-ops,
  matching the existing `RESEND_API_KEY`-missing behavior in `sendEmail`.
- No `fcmToken` on the customer profile → push silently skipped; email still sends.
- WebView load failure (bad/expired tracking link) → rely on `webview_flutter`'s default
  error page; no custom retry UI in this pass.

## Testing

- Backend: manual PATCH requests to `/api/osteq/orders/[id]/status` verifying the
  auto-status-flip on first `trackingUrl` set, and that a second update with an unchanged
  `trackingUrl` does not re-trigger the flip.
- Push: manual end-to-end check — set a tracking link on a test order via the admin UI,
  confirm a push arrives on a device with the customer app installed and logged in, and
  that tapping it opens that order's detail screen.
- Flutter: existing widget-test patterns for `order_detail_screen.dart` extended to cover
  the tracking-button visibility condition.
