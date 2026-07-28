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
