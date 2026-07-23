import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import 'category_provider.dart';
import 'currency_provider.dart';
import 'ledger_provider.dart';
import 'transaction_provider.dart';

/// Period selector for the statistics page.
enum StatsPeriod { thisMonth, lastMonth, thisYear, custom }

/// A category-expense pair used in pie charts.
class CategoryExpense {
  final Category category;
  final int totalInCents;

  const CategoryExpense(
      {required this.category, required this.totalInCents});
}

/// Statistics snapshot for the selected date range.
class StatsSnapshot {
  final int expenseInCents;
  final int incomeInCents;
  final int transactionCount;
  final List<CategoryExpense> expenseBreakdown;
  final List<CategoryExpense> incomeBreakdown;
  final String currencySymbol;

  const StatsSnapshot({
    required this.expenseInCents,
    required this.incomeInCents,
    required this.transactionCount,
    required this.expenseBreakdown,
    required this.incomeBreakdown,
    this.currencySymbol = '¥',
  });

  double get expense => expenseInCents / 100.0;
  double get income => incomeInCents / 100.0;
  double get balance => income - expense;

  String get expenseFormatted =>
      NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2)
          .format(expense);
  String get incomeFormatted =>
      NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2)
          .format(income);
  String get balanceFormatted =>
      NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2)
          .format(balance);
}

/// Provider that computes statistics for the selected period.
final statsProvider =
    FutureProvider.family<StatsSnapshot, StatsPeriod>((ref, period) async {
  ref.watch(refreshTriggerProvider);
  ref.watch(tabSwitchProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();

  DateTime start;
  DateTime end;

  switch (period) {
    case StatsPeriod.thisMonth:
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
    case StatsPeriod.lastMonth:
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 1);
    case StatsPeriod.thisYear:
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year + 1, 1, 1);
    case StatsPeriod.custom:
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
  }

  final expense =
      await repo.totalExpenseInRange(start, end, ledgerId: ledgerId);
  final income =
      await repo.totalIncomeInRange(start, end, ledgerId: ledgerId);
  final expenseCatRaw = await repo.expenseByCategory(start, end, ledgerId: ledgerId);
  final incomeCatRaw = await repo.incomeByCategory(start, end, ledgerId: ledgerId);
  final allCats = await ref.read(categoryRepositoryProvider).getAll();
  final catMap = {for (final c in allCats) c.id!: c};

  List<CategoryExpense> buildBreakdown(List<(int, int)> raw) => raw
      .where((pair) => catMap.containsKey(pair.$1))
      .map((pair) => CategoryExpense(
            category: catMap[pair.$1]!,
            totalInCents: pair.$2,
          ))
      .toList()
    ..sort((a, b) => b.totalInCents.compareTo(a.totalInCents));

  // Count transactions in range.
  final txns =
      await repo.getByDateRange(start, end, ledgerId: ledgerId);

  final defaultCurrency = await ref.read(defaultCurrencyProvider.future);

  return StatsSnapshot(
    expenseInCents: expense,
    incomeInCents: income,
    transactionCount: txns.length,
    expenseBreakdown: buildBreakdown(expenseCatRaw),
    incomeBreakdown: buildBreakdown(incomeCatRaw),
    currencySymbol: defaultCurrency.symbol,
  );
});

/// Monthly trend data for the chart.
/// (yearMonth, expenseInCents, incomeInCents)
final monthlyTrendProvider = FutureProvider<List<(String, int, int)>>((ref) {
  ref.watch(refreshTriggerProvider);
  ref.watch(tabSwitchProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .monthlyBreakdown(months: 12, ledgerId: ledgerId);
});
