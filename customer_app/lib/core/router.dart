import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/catalog/category_list_screen.dart';
import '../features/catalog/product_list_screen.dart';
import '../features/catalog/product_detail_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/cart/checkout_screen.dart';
import '../features/quotes/quotes_list_screen.dart';
import '../features/quotes/new_quote_screen.dart';
import '../features/account/account_screen.dart';
import '../features/orders/order_confirmation_screen.dart';
import '../features/orders/order_history_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/trade/trade_application_screen.dart';

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
                builder: (context, state) => ProductListScreen(
                  categoryId: state.uri.queryParameters['categoryId'],
                  categoryName: state.uri.queryParameters['categoryName'],
                ),
              ),
              GoRoute(
                path: 'products/:productId',
                name: 'productDetail',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['productId']!,
                ),
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
              GoRoute(path: 'checkout', name: 'checkout', builder: (context, state) => const CheckoutScreen()),
              GoRoute(
                path: 'confirmation/:orderId',
                name: 'orderConfirmation',
                builder: (context, state) => OrderConfirmationScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
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
              GoRoute(path: 'new', name: 'newQuote', builder: (context, state) => const NewQuoteScreen()),
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
              GoRoute(
                path: 'trade',
                name: 'tradeApplication',
                builder: (context, state) => const TradeApplicationScreen(),
              ),
              GoRoute(path: 'orders', name: 'orderHistory', builder: (context, state) => const OrderHistoryScreen()),
              GoRoute(
                path: 'orders/:id',
                name: 'orderDetail',
                builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
      ],
    ),
  ],
);
