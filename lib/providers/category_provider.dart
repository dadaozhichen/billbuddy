import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/category_repository.dart';
import '../models/category.dart';
import 'database_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  ref.watch(databaseProvider);
  return CategoryRepository.instance;
});

/// All categories, refreshed when the database is re-initialised.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

/// Expense-only categories (for the add-transaction form).
final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getByType(TransactionType.expense);
});

/// Income-only categories.
final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getByType(TransactionType.income);
});
