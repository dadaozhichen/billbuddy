import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/ledger_repository.dart';
import '../models/ledger.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  ref.watch(databaseProvider);
  return LedgerRepository.instance;
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Every ledger.
final allLedgersProvider = FutureProvider<List<Ledger>>((ref) async {
  return ref.watch(ledgerRepositoryProvider).getAll();
});

/// The currently selected ledger ID.
///
/// Persisted choice; defaults to 1 (the default ledger created on first run).
final currentLedgerIdProvider = StateProvider<int>((_) => 1);

/// The full [Ledger] object for the currently selected ID.
final currentLedgerProvider = FutureProvider<Ledger>((ref) async {
  final id = ref.watch(currentLedgerIdProvider);
  final ledger = await ref.watch(ledgerRepositoryProvider).getById(id);
  return ledger ?? Ledger(name: '个人账本');
});

/// Write operations for ledgers.
final ledgerMutationsProvider = Provider<LedgerMutations>((ref) {
  return LedgerMutations(ref);
});

class LedgerMutations {
  LedgerMutations(this._ref);
  final Ref _ref;

  Future<int> create(Ledger ledger) async {
    final id = await _ref.read(ledgerRepositoryProvider).insert(ledger);
    // Auto-switch to the new ledger.
    _ref.read(currentLedgerIdProvider.notifier).state = id;
    // Force refresh.
    _ref.invalidate(allLedgersProvider);
    return id;
  }

  Future<void> rename(int id, String name) async {
    final repo = _ref.read(ledgerRepositoryProvider);
    final existing = await repo.getById(id);
    if (existing == null) return;
    await repo.update(existing.copyWith(name: name));
    _ref.invalidate(allLedgersProvider);
  }

  Future<void> delete(int id) async {
    // Remove all transactions belonging to this ledger first.
    await _ref.read(transactionRepositoryProvider).deleteByLedger(id);
    // Then remove the ledger itself.
    await _ref.read(ledgerRepositoryProvider).delete(id);
    // Switch to the first available ledger if we deleted the active one.
    if (_ref.read(currentLedgerIdProvider) == id) {
      final remaining = await _ref.read(ledgerRepositoryProvider).getAll();
      final fallbackId = remaining.firstOrNull?.id ?? 1;
      _ref.read(currentLedgerIdProvider.notifier).state = fallbackId;
    }
    _ref.invalidate(allLedgersProvider);
  }
}
