import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/repositories/transaction_repository.dart';
import '../models/transaction.dart';
import 'currency_provider.dart';
import 'database_provider.dart';
import 'ledger_provider.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  ref.watch(databaseProvider);
  return TransactionRepository.instance;
});

// ---------------------------------------------------------------------------
// Refresh control
// ---------------------------------------------------------------------------

/// Increment this counter to signal every downstream provider to re-fetch.
final refreshTriggerProvider = StateProvider<int>((_) => 0);

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Helper to read the current ledger id in any async provider.
int _currentLedgerId(Ref ref) => ref.watch(currentLedgerIdProvider);

/// Today's transactions for the current ledger.
final todayTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final ledgerId = _currentLedgerId(ref);
  return ref.watch(transactionRepositoryProvider).getToday(ledgerId: ledgerId);
});

/// Transactions for the current month in the current ledger.
final monthTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final ledgerId = _currentLedgerId(ref);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return ref
      .watch(transactionRepositoryProvider)
      .getByDateRange(start, end, ledgerId: ledgerId);
});

// ---------------------------------------------------------------------------
// Aggregations
// ---------------------------------------------------------------------------

/// Summary of income and expense for the current month in the current ledger.
class MonthSummary {
  final int expenseInCents;
  final int incomeInCents;
  final String currencySymbol;

  const MonthSummary({
    required this.expenseInCents,
    required this.incomeInCents,
    this.currencySymbol = '¥',
  });

  double get expense => expenseInCents / 100.0;
  double get income => incomeInCents / 100.0;
  double get balance => income - expense;

  String get expenseFormatted => _fmt(expense);
  String get incomeFormatted => _fmt(income);
  String get balanceFormatted => _fmt(balance);

  String _fmt(double v) =>
      NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2)
          .format(v);
}

final monthSummaryProvider = FutureProvider<MonthSummary>((ref) async {
  ref.watch(refreshTriggerProvider);
  ref.watch(currencyRefreshProvider);
  final ledgerId = _currentLedgerId(ref);
  final repo = ref.watch(transactionRepositoryProvider);
  final currencyRepo = ref.watch(currencyRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);

  // Get default currency.
  final defaultCurrency = await ref.read(defaultCurrencyProvider.future);
  final defaultCode = defaultCurrency.code;

  // Load all transactions for the month.
  final transactions =
      await repo.getByDateRange(start, end, ledgerId: ledgerId);

  if (transactions.isEmpty) {
    return MonthSummary(
      expenseInCents: 0,
      incomeInCents: 0,
      currencySymbol: defaultCurrency.symbol,
    );
  }

  // Collect distinct non-base currencies.
  final foreignCodes = transactions
      .map((t) => t.currencyCode)
      .where((c) => c != defaultCode)
      .toSet();

  // Fetch current rates for all foreign currencies at once.
  final rateMap = <String, double>{};
  for (final code in foreignCodes) {
    final rate = await currencyRepo.getRate(code, defaultCode);
    if (rate != null) rateMap[code] = rate;
  }

  // Calculate totals using current rates.
  double expense = 0;
  double income = 0;

  for (final t in transactions) {
    final converted = t.currencyCode == defaultCode
        ? t.amount
        : t.amount * (rateMap[t.currencyCode] ?? 1);

    if (t.isExpense) {
      expense += converted;
    } else {
      income += converted;
    }
  }

  return MonthSummary(
    expenseInCents: (expense * 100).round(),
    incomeInCents: (income * 100).round(),
    currencySymbol: defaultCurrency.symbol,
  );
});

// ---------------------------------------------------------------------------
// Tab tracking (used by ShellPage to notify pages of tab switches)
// ---------------------------------------------------------------------------

/// Incremented each time the user switches to a tab, so pages like
/// StatisticsPage can re-fetch data without being destroyed by IndexedStack.
final tabSwitchProvider = StateProvider<int>((_) => 0);

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

/// Wraps CRUD and bumps [refreshTriggerProvider].
final transactionMutationsProvider = Provider<TransactionMutations>((ref) {
  return TransactionMutations(ref);
});

class TransactionMutations {
  TransactionMutations(this._ref);
  final Ref _ref;

  Future<int> add(Transaction t) async {
    final id = await _ref.read(transactionRepositoryProvider).insert(t);
    _ref.read(refreshTriggerProvider.notifier).state++;
    return id;
  }

  Future<void> update(Transaction t) async {
    await _ref.read(transactionRepositoryProvider).update(t);
    _ref.read(refreshTriggerProvider.notifier).state++;
  }

  Future<void> delete(int id) async {
    await _ref.read(transactionRepositoryProvider).delete(id);
    _ref.read(refreshTriggerProvider.notifier).state++;
  }
}
