# Osteq Customer App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Osteq customer-facing Flutter app (iOS/Android/Web) per `docs/superpowers/specs/2026-07-28-customer-app-design.md` — catalog browsing, trade signup, cart/checkout, order history, and the quote/RFQ lifecycle, consuming the backend already in this repo.

**Architecture:** A new `customer_app/` Flutter project inside this repo (mirroring `technician_app`'s placement inside `qube-technologies-platform`). `flutter_riverpod` for state, `dio` for HTTP (bearer-token interceptor), `supabase_flutter` for auth, `go_router` for navigation with a 4-tab bottom-nav shell (Catalog/Cart/Quotes/Account). Auth screens are pushed on demand ("browse first, log in at checkout") rather than gating the whole app.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12.2 (matches `technician_app`), `flutter_riverpod` ^2.6.1, `dio` ^5.7.0, `supabase_flutter` ^2.8.0, `go_router` ^14.6.2.

## Global Constraints

- Every screen fetches live from the API — no local database/cache layer (per the spec's online-only decision for v1).
- The `dio` client's request interceptor attaches `Authorization: Bearer <token>` from the current Supabase session on every request; its response interceptor maps non-2xx responses to a typed `ApiException(statusCode, message)` reading the backend's `{ error: string }` shape.
- Catalog/quote/order JSON field names must match the backend exactly (`priceInPaise`, `tier`, `accountStatus`, `quotedUnitPriceInPaise`, etc.) — these are not renamed on the Dart side.
- Auth gating is push-based, not route-redirect-based: a protected action (add to cart, submit quote, apply for trade) checks `currentSessionProvider` and pushes `/login` if null, rather than redirecting whole route subtrees.
- Match the existing repo's code style: no comments explaining *what* code does, only non-obvious *why*.
- Run every command from `C:\Users\Shoeii\osteq-platform` (this repo's root — no worktree isolation was used for the earlier backend work at the top level of this repo, so work directly here) unless a step says otherwise.

---

### Task 1: Backend — customer-facing order list/detail routes

**Files:**
- Create: `app/api/osteq/orders/route.ts`
- Create: `app/api/osteq/orders/[id]/route.ts`

**Interfaces:**
- Consumes: `requireOsteqCustomerAccess` (`@/lib/osteq/auth`), `prisma`.
- Produces: `GET /api/osteq/orders` → `{ orders: OsteqOrder[] }` (own orders, newest first, each with `items`). `GET /api/osteq/orders/[id]` → `{ order: OsteqOrder }` (with `items`), 404 if not found or not owned.

- [ ] **Step 1: Write the orders list route**

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

export async function GET(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const orders = await prisma.osteqOrder.findMany({
    where: { customerId },
    include: { items: true },
    orderBy: { createdAt: "desc" },
  });

  return NextResponse.json({ orders });
}
```

- [ ] **Step 2: Write the order detail route**

```typescript
import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { items: true },
  });
  if (!order || order.customerId !== customerId) {
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
git commit -m "Add customer-facing order list and detail routes"
```

---

### Task 2: Flutter project scaffold

**Files:**
- Create (via `flutter create`): `customer_app/` (full Flutter scaffold: `android/`, `ios/`, `web/`, `lib/main.dart`, `test/`, etc.)
- Modify: `customer_app/pubspec.yaml`
- Create: `customer_app/lib/theme/app_theme.dart`
- Modify: `customer_app/lib/main.dart`

**Interfaces:**
- Produces: `appTheme` (`ThemeData`) from `lib/theme/app_theme.dart`, consumed by Task 5's `main.dart` rewrite.

- [ ] **Step 1: Scaffold the Flutter project**

From `C:\Users\Shoeii\osteq-platform`:

```bash
flutter create --org com.osteq --project-name customer_app --platforms=android,ios,web customer_app
```
Expected: `All done!` and a new `customer_app/` directory with the standard Flutter scaffold.

- [ ] **Step 2: Replace pubspec.yaml with the app's real dependencies**

Replace `customer_app/pubspec.yaml`'s `dependencies`/`dev_dependencies` sections with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  dio: ^5.7.0
  supabase_flutter: ^2.8.0
  go_router: ^14.6.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```
(Leave `name`, `description`, `publish_to`, `version`, `environment`, and the `flutter:` section at the bottom of the generated file untouched.)

- [ ] **Step 3: Write the app theme**

```dart
import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
  appBarTheme: const AppBarTheme(centerTitle: false),
);
```

- [ ] **Step 4: Replace main.dart with a minimal placeholder**

```dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OsteqApp());
}

class OsteqApp extends StatelessWidget {
  const OsteqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osteq',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('Osteq'))),
    );
  }
}
```

- [ ] **Step 5: Fetch dependencies and verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!` (the default generated `test/widget_test.dart` will fail to compile against this new `main.dart` — delete it, since it references the generated counter-app widget tree which no longer exists):

```bash
rm -f test/widget_test.dart
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add customer_app
git commit -m "Scaffold customer_app Flutter project"
```
(This will be a large commit — the `flutter create` scaffold includes platform-specific boilerplate for android/ios/web. That's expected and correct to commit in full, same as any fresh Flutter project.)

---

### Task 3: Core — Supabase client, API client, error handling

**Files:**
- Create: `customer_app/lib/core/supabase_client.dart`
- Create: `customer_app/lib/core/api_exception.dart`
- Create: `customer_app/lib/core/api_client.dart`

**Interfaces:**
- Produces: `Future<void> initSupabase()`, `SupabaseClient get supabase` (from `supabase_client.dart`); `class ApiException implements Exception { final int statusCode; final String message; }` (from `api_exception.dart`); `class OsteqApiClient { final Dio dio; }`, `final apiClientProvider = Provider<OsteqApiClient>(...)`, `Never throwApiException(DioException e)` (from `api_client.dart`). All consumed by every repository in Tasks 4, 6-13.

- [ ] **Step 1: Write the Supabase client wrapper**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
```

- [ ] **Step 2: Write the API exception type**

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
```

- [ ] **Step 3: Write the API client**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_exception.dart';
import 'supabase_client.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

class OsteqApiClient {
  final Dio dio;

  OsteqApiClient() : dio = Dio(BaseOptions(baseUrl: apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = supabase.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final data = error.response?.data;
          final message = data is Map && data['error'] is String
              ? data['error'] as String
              : 'Something went wrong. Please try again.';
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: ApiException(error.response?.statusCode ?? 0, message),
            ),
          );
        },
      ),
    );
  }
}

final apiClientProvider = Provider<OsteqApiClient>((ref) => OsteqApiClient());

// Every repository's DioException catch block calls this instead of rethrowing the raw
// DioException, so widgets only ever need to catch ApiException — the onError interceptor
// above always attaches one, but this satisfies the type system without an unsafe cast.
Never throwApiException(DioException e) {
  final err = e.error;
  if (err is ApiException) throw err;
  throw ApiException(0, 'Network error. Please check your connection.');
}
```

- [ ] **Step 4: Verify analysis is clean**

```bash
cd customer_app
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add customer_app/lib/core
git commit -m "Add Supabase client, API client, and error handling"
```

---

### Task 4: Auth feature — repository, provider, login/signup screens

**Files:**
- Create: `customer_app/lib/features/auth/auth_repository.dart`
- Create: `customer_app/lib/features/auth/customer_profile_model.dart`
- Create: `customer_app/lib/features/auth/customer_profile_repository.dart`
- Create: `customer_app/lib/features/auth/auth_provider.dart`
- Create: `customer_app/lib/features/auth/login_screen.dart`
- Create: `customer_app/lib/features/auth/signup_screen.dart`

**Interfaces:**
- Consumes: `supabase` (Task 3), `apiClientProvider`, `throwApiException` (Task 3).
- Produces: `class CustomerProfile { final String id, email; final String? businessName, businessType, phone; final String accountStatus; bool get isTradeApproved; }`. `final authStateProvider = StreamProvider<AuthState>`, `final currentSessionProvider = Provider<Session?>`, `final customerProfileProvider = FutureProvider<CustomerProfile?>`, `final customerProfileRepositoryProvider`. `class AuthRepository { Future<void> signUp(email, password); Future<void> signIn(email, password); Future<void> signOut(); }`, `final authRepositoryProvider`. `LoginScreen`, `SignupScreen` widgets (routes `/login`, `/signup`, wired in Task 5). Consumed by every feature that needs the current customer's profile/session (Tasks 6-13) and by `core/auth_guard.dart` (Task 5).

- [ ] **Step 1: Write the auth repository**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';

class AuthRepository {
  Future<void> signUp(String email, String password) async {
    await supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
```

- [ ] **Step 2: Write the customer profile model**

```dart
class CustomerProfile {
  final String id;
  final String email;
  final String? businessName;
  final String? businessType;
  final String? phone;
  final String accountStatus;

  CustomerProfile({
    required this.id,
    required this.email,
    this.businessName,
    this.businessType,
    this.phone,
    required this.accountStatus,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      businessName: json['businessName'] as String?,
      businessType: json['businessType'] as String?,
      phone: json['phone'] as String?,
      accountStatus: json['accountStatus'] as String,
    );
  }

  bool get isTradeApproved => accountStatus == 'TRADE_APPROVED';
}
```

- [ ] **Step 3: Write the customer profile repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'customer_profile_model.dart';

class CustomerProfileRepository {
  final Dio _dio;
  CustomerProfileRepository(this._dio);

  Future<CustomerProfile> fetchOrCreate() async {
    try {
      final res = await _dio.get('/api/osteq/customers/me');
      return CustomerProfile.fromJson(res.data['profile'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return createOrUpdate();
      }
      throwApiException(e);
    }
  }

  Future<CustomerProfile> createOrUpdate({
    String? businessName,
    String? businessType,
    String? phone,
  }) async {
    try {
      final res = await _dio.post('/api/osteq/customers/me', data: {
        if (businessName != null) 'businessName': businessName,
        if (businessType != null) 'businessType': businessType,
        if (phone != null) 'phone': phone,
      });
      return CustomerProfile.fromJson(res.data['profile'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((ref) {
  return CustomerProfileRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 4: Write the auth providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'customer_profile_model.dart';
import 'customer_profile_repository.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState?.session ?? supabase.auth.currentSession;
});

final customerProfileProvider = FutureProvider<CustomerProfile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final repo = ref.watch(customerProfileRepositoryProvider);
  return repo.fetchOrCreate();
});
```

- [ ] **Step 5: Write the login screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Sign in failed. Check your email and password.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Log in'),
            ),
            TextButton(
              onPressed: () => context.pushReplacementNamed('signup'),
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the signup screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import 'auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password (min 6 characters)'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign up'),
            ),
            TextButton(
              onPressed: () => context.pushReplacementNamed('login'),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add customer_app/lib/features/auth
git commit -m "Add auth feature: repository, profile, login/signup screens"
```

---

### Task 5: App shell, router, and auth guard

**Files:**
- Create: `customer_app/lib/core/auth_guard.dart`
- Create: `customer_app/lib/core/router.dart`
- Create: `customer_app/lib/features/shell/app_shell.dart`
- Modify: `customer_app/lib/main.dart`

**Interfaces:**
- Consumes: `currentSessionProvider` (Task 4), `initSupabase` (Task 3), `appTheme` (Task 2), `LoginScreen`/`SignupScreen` (Task 4).
- Produces: `bool ensureSignedIn(BuildContext context, WidgetRef ref)` — pushes `/login` and returns `false` if no session, else `true`. `final router` (`GoRouter`) with named routes `catalog`, `productList`, `productDetail`, `cart`, `checkout`, `orderConfirmation`, `quotes`, `newQuote`, `quoteDetail`, `account`, `tradeApplication`, `orderHistory`, `orderDetail` — every later task's screens are wired into this router by name, not by hand-written path strings, so route paths stay in one place. Consumed by every screen task (6-13) via `context.push`/`context.go` using these route names.

- [ ] **Step 1: Write the auth guard**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';

bool ensureSignedIn(BuildContext context, WidgetRef ref) {
  final session = ref.read(currentSessionProvider);
  if (session == null) {
    context.pushNamed('login');
    return false;
  }
  return true;
}
```

- [ ] **Step 2: Write placeholder tab screens (real content lands in Tasks 6-13)**

These are intentionally minimal — each later task replaces the screen it owns. Create four files:

`customer_app/lib/features/catalog/category_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: const Center(child: Text('Categories load here')),
    );
  }
}
```

`customer_app/lib/features/cart/cart_screen.dart`:
```dart
import 'package:flutter/material.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: const Center(child: Text('Cart items load here')),
    );
  }
}
```

`customer_app/lib/features/quotes/quotes_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

class QuotesListScreen extends StatelessWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quotes')),
      body: const Center(child: Text('Quotes load here')),
    );
  }
}
```

`customer_app/lib/features/account/account_screen.dart`:
```dart
import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(child: Text('Profile loads here')),
    );
  }
}
```

- [ ] **Step 3: Write the bottom-nav app shell**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.request_quote_outlined), label: 'Quotes'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write the router**

```dart
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/catalog/category_list_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/quotes/quotes_list_screen.dart';
import '../features/account/account_screen.dart';
import '../features/shell/app_shell.dart';

final router = GoRouter(
  initialLocation: '/catalog',
  routes: [
    GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', name: 'signup', builder: (context, state) => const SignupScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/catalog',
            name: 'catalog',
            builder: (context, state) => const CategoryListScreen(),
            routes: [
              GoRoute(
                path: 'products',
                name: 'productList',
                builder: (context, state) => const CategoryListScreen(),
              ),
              GoRoute(
                path: 'products/:productId',
                name: 'productDetail',
                builder: (context, state) => const CategoryListScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/cart',
            name: 'cart',
            builder: (context, state) => const CartScreen(),
            routes: [
              GoRoute(path: 'checkout', name: 'checkout', builder: (context, state) => const CartScreen()),
              GoRoute(
                path: 'confirmation/:orderId',
                name: 'orderConfirmation',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/quotes',
            name: 'quotes',
            builder: (context, state) => const QuotesListScreen(),
            routes: [
              GoRoute(path: 'new', name: 'newQuote', builder: (context, state) => const QuotesListScreen()),
              GoRoute(path: ':id', name: 'quoteDetail', builder: (context, state) => const QuotesListScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/account',
            name: 'account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(path: 'trade', name: 'tradeApplication', builder: (context, state) => const AccountScreen()),
              GoRoute(path: 'orders', name: 'orderHistory', builder: (context, state) => const AccountScreen()),
              GoRoute(path: 'orders/:id', name: 'orderDetail', builder: (context, state) => const AccountScreen()),
            ],
          ),
        ]),
      ],
    ),
  ],
);
```

Each later task replaces the placeholder `builder:` for the routes it owns with the real screen widget — the route `path`/`name` values above are the interface every later task's navigation calls (`context.pushNamed('productDetail', pathParameters: {...})`) rely on; do not rename them.

- [ ] **Step 5: Rewrite main.dart to use the router and Riverpod**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
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

- [ ] **Step 6: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add customer_app/lib
git commit -m "Add app shell, router, and auth guard"
```

---

### Task 6: Catalog feature — models, repository, category and product list screens

**Files:**
- Create: `customer_app/lib/features/catalog/category_model.dart`
- Create: `customer_app/lib/features/catalog/product_model.dart`
- Create: `customer_app/lib/features/catalog/catalog_repository.dart`
- Create: `customer_app/lib/features/catalog/catalog_provider.dart`
- Modify: `customer_app/lib/features/catalog/category_list_screen.dart`
- Create: `customer_app/lib/features/catalog/product_list_screen.dart`
- Create: `customer_app/lib/widgets/price_tag.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `throwApiException` (Task 3).
- Produces: `class Category { final String id, name, slug; }`, `class CategoryRef` (same shape, embedded in `Product`), `class ProductVariant { final String id, sku; final Map<String, dynamic> attributes; final int stockQuantity, priceInPaise; final String tier; }`, `class Product { final String id, name, slug; final String? description; final List<String> images; final CategoryRef category; final List<ProductVariant> variants; }`. `final categoriesProvider = FutureProvider<List<Category>>`, `final productsProvider = FutureProvider.family<List<Product>, String?>` (parameterized by nullable `categoryId`). `PriceTag` widget taking `int priceInPaise` and `String tier`. Consumed by Task 7 (product detail), Task 8 (cart items), Task 12-13 (quote items reuse the same `Product`/`ProductVariant` shape for the catalog picker).

- [ ] **Step 1: Write the category model**

```dart
class Category {
  final String id;
  final String name;
  final String slug;

  Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}
```

- [ ] **Step 2: Write the product model**

```dart
import 'category_model.dart';

class ProductVariant {
  final String id;
  final String sku;
  final Map<String, dynamic> attributes;
  final int stockQuantity;
  final int priceInPaise;
  final String tier;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.stockQuantity,
    required this.priceInPaise,
    required this.tier,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      sku: json['sku'] as String,
      attributes: Map<String, dynamic>.from(json['attributes'] as Map),
      stockQuantity: json['stockQuantity'] as int,
      priceInPaise: json['priceInPaise'] as int,
      tier: json['tier'] as String,
    );
  }

  String get attributesLabel => attributes.values.map((v) => v.toString()).join(' / ');
}

class Product {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final List<String> images;
  final Category category;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.images,
    required this.category,
    required this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      images: (json['images'] as List).map((e) => e as String).toList(),
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      variants: (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  int get lowestPriceInPaise =>
      variants.map((v) => v.priceInPaise).reduce((a, b) => a < b ? a : b);
}
```

- [ ] **Step 3: Write the catalog repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'category_model.dart';
import 'product_model.dart';

class CatalogRepository {
  final Dio _dio;
  CatalogRepository(this._dio);

  Future<List<Category>> fetchCategories() async {
    try {
      final res = await _dio.get('/api/osteq/categories');
      return (res.data['categories'] as List)
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Product>> fetchProducts({String? categoryId}) async {
    try {
      final res = await _dio.get(
        '/api/osteq/products',
        queryParameters: categoryId != null ? {'categoryId': categoryId} : null,
      );
      return (res.data['products'] as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Product> fetchProduct(String productId) async {
    try {
      final res = await _dio.get('/api/osteq/products/$productId');
      return Product.fromJson(res.data['product'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 4: Write the catalog providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog_repository.dart';
import 'category_model.dart';
import 'product_model.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchCategories();
});

final productsProvider = FutureProvider.family<List<Product>, String?>((ref, categoryId) async {
  return ref.watch(catalogRepositoryProvider).fetchProducts(categoryId: categoryId);
});

final productDetailProvider = FutureProvider.family<Product, String>((ref, productId) async {
  return ref.watch(catalogRepositoryProvider).fetchProduct(productId);
});
```

- [ ] **Step 5: Write the price tag widget**

```dart
import 'package:flutter/material.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.priceInPaise, required this.tier});

  final int priceInPaise;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final rupees = (priceInPaise / 100).toStringAsFixed(2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('₹$rupees', style: Theme.of(context).textTheme.titleMedium),
        if (tier == 'trade') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Trade', style: TextStyle(fontSize: 11)),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 6: Replace the category list screen with the real implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'catalog_provider.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Osteq')),
      body: categoriesAsync.when(
        data: (categories) => RefreshIndicator(
          onRefresh: () => ref.refresh(categoriesProvider.future),
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'productList',
                  queryParameters: {'categoryId': category.id, 'categoryName': category.name},
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load categories: $error')),
      ),
    );
  }
}
```

- [ ] **Step 7: Write the product list screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/price_tag.dart';
import 'catalog_provider.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key, this.categoryId, this.categoryName});

  final String? categoryId;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider(categoryId));

    return Scaffold(
      appBar: AppBar(title: Text(categoryName ?? 'Products')),
      body: productsAsync.when(
        data: (products) => RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider(categoryId).future),
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: product.variants.isNotEmpty
                    ? PriceTag(
                        priceInPaise: product.lowestPriceInPaise,
                        tier: product.variants.first.tier,
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'productDetail',
                  pathParameters: {'productId': product.id},
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load products: $error')),
      ),
    );
  }
}
```

- [ ] **Step 8: Wire the product list route to the real screen**

In `customer_app/lib/core/router.dart`, add the import `import '../features/catalog/product_list_screen.dart';` and change:

```dart
              GoRoute(
                path: 'products',
                name: 'productList',
                builder: (context, state) => const CategoryListScreen(),
              ),
```

to:

```dart
              GoRoute(
                path: 'products',
                name: 'productList',
                builder: (context, state) => ProductListScreen(
                  categoryId: state.uri.queryParameters['categoryId'],
                  categoryName: state.uri.queryParameters['categoryName'],
                ),
              ),
```

- [ ] **Step 9: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add customer_app/lib/features/catalog customer_app/lib/widgets/price_tag.dart customer_app/lib/core/router.dart
git commit -m "Add catalog feature: models, repository, category and product list screens"
```

---

### Task 7: Cart feature — model, repository, provider, cart screen

**Files:**
- Create: `customer_app/lib/features/cart/cart_item_model.dart`
- Create: `customer_app/lib/features/cart/cart_repository.dart`
- Create: `customer_app/lib/features/cart/cart_provider.dart`
- Modify: `customer_app/lib/features/cart/cart_screen.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `throwApiException` (Task 3), `PriceTag` (Task 6), `ensureSignedIn` (Task 5).
- Produces: `class CartItem { final String id, variantId, sku; final int quantity, priceInPaise; final String tier; }`. `class CartRepository { Future<List<CartItem>> fetch(); Future<void> addItem(String variantId, int quantity); Future<void> updateQuantity(String itemId, int quantity); Future<void> removeItem(String itemId); }`. `final cartProvider = FutureProvider<List<CartItem>>` (also exposes a manual refresh via `ref.refresh(cartProvider.future)` — every mutating call site refreshes it after success). Consumed by Task 8 (add-to-cart button), Task 9 (checkout reads the cart total).

- [ ] **Step 1: Write the cart item model**

```dart
class CartItem {
  final String id;
  final String variantId;
  final String sku;
  final int quantity;
  final int priceInPaise;
  final String tier;

  CartItem({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.quantity,
    required this.priceInPaise,
    required this.tier,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      sku: json['sku'] as String,
      quantity: json['quantity'] as int,
      priceInPaise: json['priceInPaise'] as int,
      tier: json['tier'] as String,
    );
  }

  int get lineTotalInPaise => priceInPaise * quantity;
}
```

- [ ] **Step 2: Write the cart repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'cart_item_model.dart';

class CartRepository {
  final Dio _dio;
  CartRepository(this._dio);

  Future<List<CartItem>> fetch() async {
    try {
      final res = await _dio.get('/api/osteq/cart');
      return (res.data['items'] as List)
          .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> addItem(String variantId, int quantity) async {
    try {
      await _dio.post('/api/osteq/cart', data: {'variantId': variantId, 'quantity': quantity});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    try {
      await _dio.patch('/api/osteq/cart/items/$itemId', data: {'quantity': quantity});
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await _dio.delete('/api/osteq/cart/items/$itemId');
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 3: Write the cart provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_item_model.dart';
import 'cart_repository.dart';

final cartProvider = FutureProvider<List<CartItem>>((ref) async {
  return ref.watch(cartRepositoryProvider).fetch();
});
```

- [ ] **Step 4: Replace the cart screen with the real implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../../widgets/price_tag.dart';
import 'cart_provider.dart';
import 'cart_repository.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cartAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Your cart is empty'));
          }
          final total = items.fold<int>(0, (sum, i) => sum + i.lineTotalInPaise);
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    Future<void> handleError(Future<void> Function() action) async {
                      try {
                        await action();
                        ref.invalidate(cartProvider);
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    }

                    return ListTile(
                      title: Text(item.sku),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: item.quantity > 1
                                ? () => handleError(() => ref
                                    .read(cartRepositoryProvider)
                                    .updateQuantity(item.id, item.quantity - 1))
                                : null,
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => handleError(() => ref
                                .read(cartRepositoryProvider)
                                .updateQuantity(item.id, item.quantity + 1)),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriceTag(priceInPaise: item.lineTotalInPaise, tier: item.tier),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                handleError(() => ref.read(cartRepositoryProvider).removeItem(item.id)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => context.pushNamed('checkout'),
                  child: Text('Checkout — ₹${(total / 100).toStringAsFixed(2)}'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load cart: $error')),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add customer_app/lib/features/cart
git commit -m "Add cart feature: model, repository, provider, cart screen"
```

---

### Task 8: Product detail screen — variant picker, add to cart

**Files:**
- Modify: `customer_app/lib/core/router.dart`
- Create: `customer_app/lib/features/catalog/product_detail_screen.dart`

**Interfaces:**
- Consumes: `productDetailProvider` (Task 6), `cartRepositoryProvider`, `cartProvider` (Task 7), `ensureSignedIn` (Task 5).

- [ ] **Step 1: Write the product detail screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../core/auth_guard.dart';
import '../../widgets/price_tag.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_repository.dart';
import 'catalog_provider.dart';
import 'product_model.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  bool _adding = false;

  Future<void> _addToCart() async {
    if (!ensureSignedIn(context, ref)) return;
    final variant = _selectedVariant;
    if (variant == null) return;

    setState(() => _adding = true);
    try {
      await ref.read(cartRepositoryProvider).addItem(variant.id, _quantity);
      ref.invalidate(cartProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: productAsync.when(
        data: (product) {
          _selectedVariant ??= product.variants.isNotEmpty ? product.variants.first : null;
          final variant = _selectedVariant;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                if (product.description != null) ...[
                  const SizedBox(height: 8),
                  Text(product.description!),
                ],
                const SizedBox(height: 16),
                if (product.variants.length > 1)
                  DropdownButton<ProductVariant>(
                    value: variant,
                    isExpanded: true,
                    items: product.variants
                        .map((v) => DropdownMenuItem(value: v, child: Text(v.attributesLabel)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVariant = v),
                  ),
                if (variant != null) ...[
                  const SizedBox(height: 12),
                  PriceTag(priceInPaise: variant.priceInPaise, tier: variant.tier),
                  const SizedBox(height: 4),
                  Text('${variant.stockQuantity} in stock'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text('$_quantity'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: variant == null || _adding ? null : _addToCart,
                  child: _adding
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add to cart'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load product: $error')),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the product detail route to the real screen**

In `customer_app/lib/core/router.dart`, add the import `import '../features/catalog/product_detail_screen.dart';` and change:

```dart
              GoRoute(
                path: 'products/:productId',
                name: 'productDetail',
                builder: (context, state) => const CategoryListScreen(),
              ),
```

to:

```dart
              GoRoute(
                path: 'products/:productId',
                name: 'productDetail',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['productId']!,
                ),
              ),
```

- [ ] **Step 3: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add customer_app/lib/features/catalog/product_detail_screen.dart customer_app/lib/core/router.dart
git commit -m "Add product detail screen with variant picker and add-to-cart"
```

---

### Task 9: Checkout, order confirmation, and order history/detail

**Files:**
- Create: `customer_app/lib/features/orders/order_model.dart`
- Create: `customer_app/lib/features/orders/orders_repository.dart`
- Create: `customer_app/lib/features/orders/orders_provider.dart`
- Create: `customer_app/lib/features/cart/checkout_screen.dart`
- Create: `customer_app/lib/features/orders/order_confirmation_screen.dart`
- Create: `customer_app/lib/features/orders/order_history_screen.dart`
- Create: `customer_app/lib/features/orders/order_detail_screen.dart`
- Modify: `customer_app/lib/core/router.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `throwApiException` (Task 3), `cartProvider` (Task 7), `PriceTag` (Task 6).
- Produces: `class OrderItem { final String id, variantId; final int quantity, unitPriceInPaise; }`, `class Order { final String id, status, shippingAddress; final String? trackingNumber; final int totalInPaise; final DateTime createdAt; final List<OrderItem> items; }`. `class OrdersRepository { Future<Order> checkout(String shippingAddress); Future<List<Order>> fetchAll(); Future<Order> fetchOne(String orderId); }`. `final ordersProvider = FutureProvider<List<Order>>`, `final orderDetailProvider = FutureProvider.family<Order, String>`. Consumed by Task 13 (accepted quote also produces an `Order`, reusing this model).

- [ ] **Step 1: Write the order models**

```dart
class OrderItem {
  final String id;
  final String variantId;
  final int quantity;
  final int unitPriceInPaise;

  OrderItem({
    required this.id,
    required this.variantId,
    required this.quantity,
    required this.unitPriceInPaise,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      quantity: json['quantity'] as int,
      unitPriceInPaise: json['unitPriceInPaise'] as int,
    );
  }
}

class Order {
  final String id;
  final String status;
  final String shippingAddress;
  final String? trackingNumber;
  final int totalInPaise;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.shippingAddress,
    this.trackingNumber,
    required this.totalInPaise,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      shippingAddress: json['shippingAddress'] as String,
      trackingNumber: json['trackingNumber'] as String?,
      totalInPaise: json['totalInPaise'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

- [ ] **Step 2: Write the orders repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'order_model.dart';

class OrdersRepository {
  final Dio _dio;
  OrdersRepository(this._dio);

  Future<Order> checkout(String shippingAddress) async {
    try {
      final res = await _dio.post('/api/osteq/checkout', data: {'shippingAddress': shippingAddress});
      return Order.fromJson(res.data['order'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Order>> fetchAll() async {
    try {
      final res = await _dio.get('/api/osteq/orders');
      return (res.data['orders'] as List)
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Order> fetchOne(String orderId) async {
    try {
      final res = await _dio.get('/api/osteq/orders/$orderId');
      return Order.fromJson(res.data['order'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 3: Write the orders providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_model.dart';
import 'orders_repository.dart';

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  return ref.watch(ordersRepositoryProvider).fetchAll();
});

final orderDetailProvider = FutureProvider.family<Order, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).fetchOne(orderId);
});
```

- [ ] **Step 4: Write the checkout screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../orders/orders_repository.dart';
import 'cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _placeOrder() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(ordersRepositoryProvider).checkout(_addressController.text.trim());
      ref.invalidate(cartProvider);
      if (mounted) {
        context.pushReplacementNamed('orderConfirmation', pathParameters: {'orderId': order.id});
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Shipping address'),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting || _addressController.text.trim().isEmpty ? null : _placeOrder,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the order confirmation screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'orders_provider.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order placed')),
      body: orderAsync.when(
        data: (order) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              Text('Order #${order.id.substring(0, 8)} confirmed'),
              const SizedBox(height: 4),
              Text('Total: ₹${(order.totalInPaise / 100).toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.goNamed('catalog'),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load order: $error')),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the order history screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'orders_provider.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order history')),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('Order #${order.id.substring(0, 8)}'),
                subtitle: Text('${order.status} — ₹${(order.totalInPaise / 100).toStringAsFixed(2)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('orderDetail', pathParameters: {'id': order.id}),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load orders: $error')),
      ),
    );
  }
}
```

- [ ] **Step 7: Write the order detail screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_provider.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order detail')),
      body: orderAsync.when(
        data: (order) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Status: ${order.status}'),
            Text('Shipping to: ${order.shippingAddress}'),
            if (order.trackingNumber != null) Text('Tracking: ${order.trackingNumber}'),
            const Divider(height: 32),
            ...order.items.map((item) => ListTile(
                  title: Text('Variant ${item.variantId.substring(0, 8)}'),
                  subtitle: Text('Qty: ${item.quantity}'),
                  trailing: Text('₹${(item.unitPriceInPaise * item.quantity / 100).toStringAsFixed(2)}'),
                )),
            const Divider(height: 32),
            Text(
              'Total: ₹${(order.totalInPaise / 100).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load order: $error')),
      ),
    );
  }
}
```

- [ ] **Step 8: Wire the checkout, order confirmation, history, and detail routes**

In `customer_app/lib/core/router.dart`, add the imports:

```dart
import '../features/cart/checkout_screen.dart';
import '../features/orders/order_confirmation_screen.dart';
import '../features/orders/order_history_screen.dart';
import '../features/orders/order_detail_screen.dart';
```

Change the `cart` branch's nested routes from:

```dart
              GoRoute(path: 'checkout', name: 'checkout', builder: (context, state) => const CartScreen()),
              GoRoute(
                path: 'confirmation/:orderId',
                name: 'orderConfirmation',
                builder: (context, state) => const CartScreen(),
              ),
```

to:

```dart
              GoRoute(path: 'checkout', name: 'checkout', builder: (context, state) => const CheckoutScreen()),
              GoRoute(
                path: 'confirmation/:orderId',
                name: 'orderConfirmation',
                builder: (context, state) => OrderConfirmationScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
              ),
```

Change the `account` branch's nested routes from:

```dart
              GoRoute(path: 'orders', name: 'orderHistory', builder: (context, state) => const AccountScreen()),
              GoRoute(path: 'orders/:id', name: 'orderDetail', builder: (context, state) => const AccountScreen()),
```

to:

```dart
              GoRoute(path: 'orders', name: 'orderHistory', builder: (context, state) => const OrderHistoryScreen()),
              GoRoute(
                path: 'orders/:id',
                name: 'orderDetail',
                builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
```

- [ ] **Step 9: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add customer_app/lib/features/orders customer_app/lib/features/cart/checkout_screen.dart customer_app/lib/core/router.dart
git commit -m "Add checkout, order confirmation, and order history/detail screens"
```

---

### Task 10: Trade application feature — form and status

**Files:**
- Create: `customer_app/lib/features/trade/trade_application_model.dart`
- Create: `customer_app/lib/features/trade/trade_application_repository.dart`
- Create: `customer_app/lib/features/trade/trade_application_screen.dart`
- Modify: `customer_app/lib/core/router.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `throwApiException` (Task 3), `customerProfileProvider` (Task 4).
- Produces: `class TradeApplication { final String id, status; final String? rejectionReason; }`. `class TradeApplicationRepository { Future<TradeApplication> submit({required businessName, required businessType, required phone, String? taxId}); }`.

- [ ] **Step 1: Write the trade application model**

```dart
class TradeApplication {
  final String id;
  final String status;
  final String? rejectionReason;

  TradeApplication({required this.id, required this.status, this.rejectionReason});

  factory TradeApplication.fromJson(Map<String, dynamic> json) {
    return TradeApplication(
      id: json['id'] as String,
      status: json['status'] as String,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
```

- [ ] **Step 2: Write the trade application repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'trade_application_model.dart';

class TradeApplicationRepository {
  final Dio _dio;
  TradeApplicationRepository(this._dio);

  Future<TradeApplication> submit({
    required String businessName,
    required String businessType,
    required String phone,
    String? taxId,
  }) async {
    try {
      final res = await _dio.post('/api/osteq/trade-applications', data: {
        'businessName': businessName,
        'businessType': businessType,
        'phone': phone,
        if (taxId != null) 'taxId': taxId,
      });
      return TradeApplication.fromJson(res.data['application'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final tradeApplicationRepositoryProvider = Provider<TradeApplicationRepository>((ref) {
  return TradeApplicationRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 3: Write the trade application screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../auth/auth_provider.dart';
import 'trade_application_repository.dart';

class TradeApplicationScreen extends ConsumerStatefulWidget {
  const TradeApplicationScreen({super.key});

  @override
  ConsumerState<TradeApplicationScreen> createState() => _TradeApplicationScreenState();
}

class _TradeApplicationScreenState extends ConsumerState<TradeApplicationScreen> {
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _submitted = false;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(tradeApplicationRepositoryProvider).submit(
            businessName: _businessNameController.text.trim(),
            businessType: _businessTypeController.text.trim(),
            phone: _phoneController.text.trim(),
            taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
          );
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trade account')),
      body: profileAsync.when(
        data: (profile) {
          if (_submitted || profile?.accountStatus == 'PENDING') {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your trade application is under review.'),
            );
          }
          if (profile?.accountStatus == 'TRADE_APPROVED') {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your trade account is approved — trade pricing is active.'),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile?.accountStatus == 'REJECTED')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Your previous application was not approved. You can reapply below.'),
                  ),
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _businessTypeController,
                  decoration: const InputDecoration(labelText: 'Business type (e.g. installer)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(labelText: 'Tax ID (optional)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit application'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the trade application route**

In `customer_app/lib/core/router.dart`, add the import `import '../features/trade/trade_application_screen.dart';` and change:

```dart
              GoRoute(path: 'trade', name: 'tradeApplication', builder: (context, state) => const AccountScreen()),
```

to:

```dart
              GoRoute(
                path: 'trade',
                name: 'tradeApplication',
                builder: (context, state) => const TradeApplicationScreen(),
              ),
```

- [ ] **Step 5: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add customer_app/lib/features/trade customer_app/lib/core/router.dart
git commit -m "Add trade application feature: form and status"
```

---

### Task 11: Quotes feature — models, repository, list, and new quote builder

**Files:**
- Create: `customer_app/lib/features/quotes/quote_model.dart`
- Create: `customer_app/lib/features/quotes/quotes_repository.dart`
- Create: `customer_app/lib/features/quotes/quotes_provider.dart`
- Modify: `customer_app/lib/features/quotes/quotes_list_screen.dart`
- Create: `customer_app/lib/features/quotes/new_quote_screen.dart`
- Modify: `customer_app/lib/core/router.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `throwApiException` (Task 3), `categoriesProvider`/`productsProvider` (Task 6), `ensureSignedIn` (Task 5), `class Order` (`../orders/order_model.dart`, Task 9 — `QuotesRepository.respond` returns one, since accepting a quote converts it to an order).
- Produces: `class QuoteItem { final String id; final String? productVariantId, description; final int quantity; final int? quotedUnitPriceInPaise; final String? notes; }`, `class QuoteMessage { final String id; final String? authorProfileId, authorCustomerId; final String body; final DateTime createdAt; bool get isFromStaff; }`, `class Quote { final String id, status; final DateTime createdAt; final List<QuoteItem> items; final List<QuoteMessage> messages; bool get allItemsPriced; int get totalInPaise; }`. `class QuotesRepository { Future<Quote> submit(List<Map<String,dynamic>> items); Future<List<Quote>> fetchAll(); Future<Quote> fetchOne(String quoteId); Future<void> addMessage(String quoteId, String body, {bool requestRevision}); Future<Order> respond(String quoteId, String decision, {String? shippingAddress}); }`. `final quotesProvider = FutureProvider<List<Quote>>`, `final quoteDetailProvider = FutureProvider.family<Quote, String>`. Consumed by Task 12 (quote detail screen).

- [ ] **Step 1: Write the quote models**

```dart
class QuoteItem {
  final String id;
  final String? productVariantId;
  final String? description;
  final int quantity;
  final int? quotedUnitPriceInPaise;
  final String? notes;

  QuoteItem({
    required this.id,
    this.productVariantId,
    this.description,
    required this.quantity,
    this.quotedUnitPriceInPaise,
    this.notes,
  });

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      id: json['id'] as String,
      productVariantId: json['productVariantId'] as String?,
      description: json['description'] as String?,
      quantity: json['quantity'] as int,
      quotedUnitPriceInPaise: json['quotedUnitPriceInPaise'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

class QuoteMessage {
  final String id;
  final String? authorProfileId;
  final String? authorCustomerId;
  final String body;
  final DateTime createdAt;

  QuoteMessage({
    required this.id,
    this.authorProfileId,
    this.authorCustomerId,
    required this.body,
    required this.createdAt,
  });

  factory QuoteMessage.fromJson(Map<String, dynamic> json) {
    return QuoteMessage(
      id: json['id'] as String,
      authorProfileId: json['authorProfileId'] as String?,
      authorCustomerId: json['authorCustomerId'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isFromStaff => authorProfileId != null;
}

class Quote {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<QuoteItem> items;
  final List<QuoteMessage> messages;

  Quote({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
    this.messages = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((i) => QuoteItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => QuoteMessage.fromJson(m as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  bool get allItemsPriced => items.every((i) => i.quotedUnitPriceInPaise != null);

  int get totalInPaise =>
      items.fold(0, (sum, i) => sum + (i.quotedUnitPriceInPaise ?? 0) * i.quantity);
}
```

- [ ] **Step 2: Write the quotes repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../orders/order_model.dart';
import 'quote_model.dart';

class QuotesRepository {
  final Dio _dio;
  QuotesRepository(this._dio);

  Future<Quote> submit(List<Map<String, dynamic>> items) async {
    try {
      final res = await _dio.post('/api/osteq/quotes', data: {'items': items});
      return Quote.fromJson(res.data['quote'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<Quote>> fetchAll() async {
    try {
      final res = await _dio.get('/api/osteq/quotes');
      return (res.data['quotes'] as List)
          .map((q) => Quote.fromJson(q as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Quote> fetchOne(String quoteId) async {
    try {
      final res = await _dio.get('/api/osteq/quotes/$quoteId');
      return Quote.fromJson(res.data['quote'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<void> addMessage(String quoteId, String body, {bool requestRevision = false}) async {
    try {
      await _dio.post('/api/osteq/quotes/$quoteId/messages', data: {
        'body': body,
        if (requestRevision) 'requestRevision': true,
      });
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<Order> respond(String quoteId, String decision, {String? shippingAddress}) async {
    try {
      final res = await _dio.post('/api/osteq/quotes/$quoteId/respond', data: {
        'decision': decision,
        if (shippingAddress != null) 'shippingAddress': shippingAddress,
      });
      return Order.fromJson(res.data['order'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(apiClientProvider).dio);
});
```

- [ ] **Step 3: Write the quotes providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quote_model.dart';
import 'quotes_repository.dart';

final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  return ref.watch(quotesRepositoryProvider).fetchAll();
});

final quoteDetailProvider = FutureProvider.family<Quote, String>((ref, quoteId) async {
  return ref.watch(quotesRepositoryProvider).fetchOne(quoteId);
});
```

- [ ] **Step 4: Replace the quotes list screen with the real implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_guard.dart';
import 'quotes_provider.dart';

class QuotesListScreen extends ConsumerWidget {
  const QuotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quotes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!ensureSignedIn(context, ref)) return;
          context.pushNamed('newQuote');
        },
        child: const Icon(Icons.add),
      ),
      body: quotesAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return const Center(child: Text('No quotes yet'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(quotesProvider.future),
            child: ListView.builder(
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return ListTile(
                  title: Text('Quote #${quote.id.substring(0, 8)}'),
                  subtitle: Text(quote.status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('quoteDetail', pathParameters: {'id': quote.id}),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load quotes: $error')),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the new quote builder screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import '../catalog/catalog_provider.dart';
import '../catalog/product_model.dart';
import 'quotes_provider.dart';
import 'quotes_repository.dart';

class _DraftLine {
  final ProductVariant? variant;
  final String? productName;
  final String? description;
  int quantity;

  _DraftLine({this.variant, this.productName, this.description, this.quantity = 1});
}

class NewQuoteScreen extends ConsumerStatefulWidget {
  const NewQuoteScreen({super.key});

  @override
  ConsumerState<NewQuoteScreen> createState() => _NewQuoteScreenState();
}

class _NewQuoteScreenState extends ConsumerState<NewQuoteScreen> {
  final List<_DraftLine> _lines = [];
  final _customDescriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  void _addCustomLine() {
    final description = _customDescriptionController.text.trim();
    if (description.isEmpty) return;
    setState(() {
      _lines.add(_DraftLine(description: description));
      _customDescriptionController.clear();
    });
  }

  Future<void> _pickCatalogItem() async {
    final products = await ref.read(productsProvider(null).future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<Product>(
      context: context,
      builder: (context) => ListView(
        children: products
            .map((p) => ListTile(title: Text(p.name), onTap: () => Navigator.pop(context, p)))
            .toList(),
      ),
    );
    if (selected == null || selected.variants.isEmpty) return;
    setState(() {
      _lines.add(_DraftLine(variant: selected.variants.first, productName: selected.name));
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final items = _lines
          .map((line) => {
                if (line.variant != null) 'productVariantId': line.variant!.id,
                if (line.description != null) 'description': line.description,
                'quantity': line.quantity,
              })
          .toList();
      await ref.read(quotesRepositoryProvider).submit(items);
      ref.invalidate(quotesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New quote')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: _lines
                    .map((line) => ListTile(
                          title: Text(line.productName ?? line.description ?? ''),
                          subtitle: Text('Qty: ${line.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _lines.remove(line)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickCatalogItem,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Add catalog item'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customDescriptionController,
                    decoration: const InputDecoration(labelText: 'Custom item description'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addCustomLine),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _lines.isEmpty || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit quote'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the new quote route**

In `customer_app/lib/core/router.dart`, add the import `import '../features/quotes/new_quote_screen.dart';` and change:

```dart
              GoRoute(path: 'new', name: 'newQuote', builder: (context, state) => const QuotesListScreen()),
```

to:

```dart
              GoRoute(path: 'new', name: 'newQuote', builder: (context, state) => const NewQuoteScreen()),
```

- [ ] **Step 7: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add customer_app/lib/features/quotes customer_app/lib/core/router.dart
git commit -m "Add quotes feature: models, repository, list, and new quote builder"
```

---

### Task 12: Quote detail screen — messages thread, accept/reject

**Files:**
- Modify: `customer_app/lib/core/router.dart`
- Create: `customer_app/lib/features/quotes/quote_detail_screen.dart`

**Interfaces:**
- Consumes: `quoteDetailProvider`, `quotesRepositoryProvider` (Task 11), `quotesProvider` (Task 11, invalidated on mutation).

- [ ] **Step 1: Write the quote detail screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_exception.dart';
import 'quote_model.dart';
import 'quotes_provider.dart';
import 'quotes_repository.dart';

class QuoteDetailScreen extends ConsumerStatefulWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  final _messageController = TextEditingController();
  final _addressController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _sendMessage({required bool requestRevision}) async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(quotesRepositoryProvider)
          .addMessage(widget.quoteId, body, requestRevision: requestRevision);
      _messageController.clear();
      ref.invalidate(quoteDetailProvider(widget.quoteId));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String decision) async {
    if (decision == 'ACCEPTED' && _addressController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a shipping address to accept.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(quotesRepositoryProvider).respond(
            widget.quoteId,
            decision,
            shippingAddress: decision == 'ACCEPTED' ? _addressController.text.trim() : null,
          );
      ref.invalidate(quotesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quoteDetailProvider(widget.quoteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quote')),
      body: quoteAsync.when(
        data: (quote) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Status: ${quote.status}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...quote.items.map((item) => ListTile(
                  title: Text(item.description ?? 'Variant ${item.productVariantId?.substring(0, 8)}'),
                  subtitle: Text('Qty: ${item.quantity}'),
                  trailing: Text(
                    item.quotedUnitPriceInPaise != null
                        ? '₹${(item.quotedUnitPriceInPaise! * item.quantity / 100).toStringAsFixed(2)}'
                        : 'Not yet priced',
                  ),
                )),
            if (quote.allItemsPriced) ...[
              const Divider(height: 32),
              Text(
                'Total: ₹${(quote.totalInPaise / 100).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const Divider(height: 32),
            Text('Messages', style: Theme.of(context).textTheme.titleMedium),
            ...quote.messages.map((m) => ListTile(
                  title: Text(m.body),
                  subtitle: Text(m.isFromStaff ? 'Osteq staff' : 'You'),
                )),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Add a message'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _sendMessage(requestRevision: false),
                  child: const Text('Send message'),
                ),
                if (quote.status == 'QUOTED')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _sendMessage(requestRevision: true),
                    child: const Text('Request revision'),
                  ),
              ],
            ),
            if (quote.status == 'QUOTED') ...[
              const Divider(height: 32),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Shipping address (to accept)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy || !quote.allItemsPriced ? null : () => _respond('ACCEPTED'),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _respond('REJECTED'),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load quote: $error')),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the quote detail route**

In `customer_app/lib/core/router.dart`, add the import `import '../features/quotes/quote_detail_screen.dart';` and change:

```dart
              GoRoute(path: ':id', name: 'quoteDetail', builder: (context, state) => const QuotesListScreen()),
```

to:

```dart
              GoRoute(
                path: ':id',
                name: 'quoteDetail',
                builder: (context, state) => QuoteDetailScreen(quoteId: state.pathParameters['id']!),
              ),
```

- [ ] **Step 3: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add customer_app/lib/features/quotes/quote_detail_screen.dart customer_app/lib/core/router.dart
git commit -m "Add quote detail screen with message thread and accept/reject"
```

---

### Task 13: Account tab — profile, trade status, order history link, logout

**Files:**
- Modify: `customer_app/lib/features/account/account_screen.dart`

**Interfaces:**
- Consumes: `customerProfileProvider`, `authRepositoryProvider` (Task 4), `ensureSignedIn` (Task 5).

- [ ] **Step 1: Replace the account screen with the real implementation**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_repository.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.pushNamed('login'),
            child: const Text('Log in'),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(customerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(profile?.email ?? '', style: Theme.of(context).textTheme.titleMedium),
            if (profile?.businessName != null) Text(profile!.businessName!),
            const SizedBox(height: 8),
            Text('Trade status: ${profile?.accountStatus ?? 'PENDING'}'),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Trade account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('tradeApplication'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('orderHistory'),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.goNamed('catalog');
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis is clean**

```bash
cd customer_app
flutter pub get
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add customer_app/lib/features/account/account_screen.dart
git commit -m "Add account tab: profile, trade status, order history link, logout"
```

---

### Task 14: Manual verification on device

**Files:** None — verification only.

**Interfaces:** None.

This task requires a real Supabase project and the backend's schema actually pushed to it —
neither exists yet as of this plan (per this repo's README: "let's keep local for now" was
the decision when this repo was created). Complete the prerequisites below before the
device run.

- [ ] **Step 1: Prerequisites — real backend to test against**

1. Create a Supabase project (supabase.com), copy its URL/anon key/service role key and
   Postgres connection strings into a `.env.local` in `C:\Users\Shoeii\osteq-platform`
   (see `.env.example`).
2. From the repo root: `npx prisma migrate dev` — creates every `osteq_*` table and the
   `staff` table for real.
3. Start the backend: `npm run dev` — note the port (default 3000).
4. Create a staff account (Supabase dashboard → Authentication → Add user, then insert a
   matching row into `staff` per the README) so you can manually approve trade
   applications and price quotes during testing, the same manual steps used throughout
   this backend's own development.

- [ ] **Step 2: Find your machine's LAN IP for the device to reach the dev server**

```bash
ipconfig | grep -A 5 "Wireless LAN adapter Wi-Fi"
```
Note the `IPv4 Address` (e.g. `192.168.1.42`) — a physical device can't reach
`localhost:3000` on your laptop, it needs this LAN address, and both devices must be on
the same network.

- [ ] **Step 3: Connect the OnePlus device**

```bash
flutter devices
```
Expected: your OnePlus appears in the list. If not: enable Developer Options → USB
debugging on the phone, reconnect the USB cable, and accept the "Allow USB debugging?"
prompt on the phone's screen if it appears.

- [ ] **Step 4: Run the app on the device**

From `customer_app/`:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:3000 --dart-define=SUPABASE_URL=<your-supabase-url> --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key>
```
Expected: the app builds and launches on the OnePlus, showing the catalog tab (empty —
no products seeded yet).

- [ ] **Step 5: Seed one product and verify the catalog → cart → checkout golden path**

With the backend running, seed a category/product/variant (same script shape used during
the backend's own manual verification):

```bash
node -e "
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();
(async () => {
  const category = await p.osteqCategory.create({ data: { name: 'HDMI Cables', slug: 'hdmi-cables' } });
  const product = await p.osteqProduct.create({ data: { categoryId: category.id, name: 'Osteq HDMI Cable', slug: 'osteq-hdmi-cable' } });
  await p.osteqProductVariant.create({ data: { productId: product.id, sku: 'HDMI-6FT', attributes: { length: '6ft' }, retailPriceInPaise: 150000, tradePriceInPaise: 100000, stockQuantity: 5 } });
  console.log('seeded');
  return p.\$disconnect();
})();
"
```
On the device: pull-to-refresh the catalog tab, tap into the category, tap the product,
add it to cart (this should prompt login/signup on first attempt — sign up, then retry),
go to the Cart tab, tap Checkout, enter a shipping address, place the order. Expected:
order confirmation screen appears, and the order shows up in Account → Order history.

- [ ] **Step 6: Verify the quote golden path**

On the device: Quotes tab → the `+` button → add the seeded catalog item → submit. As
staff (via curl, using a bearer token from the staff account created in Step 1 — same
pattern as the backend's own manual quote-pricing verification), price the quote and move
it to `QUOTED`. Back on the device: pull-to-refresh the quote detail screen, confirm the
price now shows, enter a shipping address, tap Accept. Expected: the quote's status moves
to `CONVERTED_TO_ORDER` and the resulting order appears in Order history.

- [ ] **Step 7: Clean up test data**

```bash
node -e "
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();
(async () => {
  await p.osteqOrderItem.deleteMany({});
  await p.osteqOrder.deleteMany({});
  await p.osteqQuoteMessage.deleteMany({});
  await p.osteqQuoteItem.deleteMany({});
  await p.osteqQuote.deleteMany({});
  await p.osteqCartItem.deleteMany({});
  await p.osteqCart.deleteMany({});
  await p.osteqProductVariant.deleteMany({});
  await p.osteqProduct.deleteMany({});
  await p.osteqCategory.deleteMany({});
  console.log('cleaned up');
  return p.\$disconnect();
})();
"
```
Delete the test customer/staff Supabase Auth users via the dashboard if you don't want to
keep them for future development.

---

## Post-plan: merge and deploy

Not a task in this plan:

1. This work was done directly on `master` in `osteq-platform` (a solo, brand-new repo,
   not a shared checkout) — no merge step needed. If you'd prefer feature-branch hygiene
   going forward, start branching from here.
2. Deploying the backend to Vercel and distributing the app (TestFlight/Play Console
   internal testing, Firebase App Distribution, or a Web build) is a separate decision —
   ask the user before doing either, since both are externally visible actions.
3. The admin panel (the third and final Osteq sub-project) still has no code — it's the
   next spec/plan cycle once this app's golden paths are verified.
