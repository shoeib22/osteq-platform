import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_item_model.dart';
import 'cart_repository.dart';

final cartProvider = FutureProvider<List<CartItem>>((ref) async {
  return ref.watch(cartRepositoryProvider).fetch();
});
