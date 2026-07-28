import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quote_model.dart';
import 'quotes_repository.dart';

final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  return ref.watch(quotesRepositoryProvider).fetchAll();
});

final quoteDetailProvider = FutureProvider.family<Quote, String>((ref, quoteId) async {
  return ref.watch(quotesRepositoryProvider).fetchOne(quoteId);
});
