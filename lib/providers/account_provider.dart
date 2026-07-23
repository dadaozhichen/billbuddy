import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/account_repository.dart';
import '../models/account.dart';
import 'database_provider.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  ref.watch(databaseProvider);
  return AccountRepository.instance;
});

/// All accounts, in display order.
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  return ref.watch(accountRepositoryProvider).getAll();
});
