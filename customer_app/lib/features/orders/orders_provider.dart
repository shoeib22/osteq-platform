import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_model.dart';
import 'orders_repository.dart';

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  return ref.watch(ordersRepositoryProvider).fetchAll();
});

final orderDetailProvider = FutureProvider.family<Order, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).fetchOne(orderId);
});
