import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/ledger.dart';
import '../models/transaction.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';
import 'create_ledger_sheet.dart';

/// Common currency symbols for display.
const _currencySymbols = <String, String>{
  'CNY': '¥',
  'USD': '\$',
  'EUR': '€',
  'JPY': '¥',
  'GBP': '£',
  'HKD': 'HK\$',
  'KRW': '₩',
  'THB': '฿',
};

/// Main tab showing today's transactions and month summary.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthSummaryProvider);
    final monthTxsAsync = ref.watch(monthTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final currentLedgerAsync = ref.watch(currentLedgerProvider);
    final allLedgersAsync = ref.watch(allLedgersProvider);

    return Scaffold(
      appBar: AppBar(
        title: currentLedgerAsync.when(
          data: (ledger) => GestureDetector(
            onTap: () => _showLedgerSwitcher(
                context, ref, ledger, allLedgersAsync),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ledger.name),
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          ),
          loading: () => const Text('BillBuddy'),
          error: (_, _) => const Text('BillBuddy'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: '新建账本',
            onPressed: () => _showCreateLedger(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(refreshTriggerProvider),
        child: ListView(
          children: [
            // ── Summary card ─────────────────────────────────
            summaryAsync.when(
              data: (s) => SummaryCard(
                expenseFormatted: s.expenseFormatted,
                incomeFormatted: s.incomeFormatted,
                balanceFormatted: s.balanceFormatted,
                expenseInCents: s.expenseInCents,
                incomeInCents: s.incomeInCents,
              ),
              loading: () => const Card(
                margin: EdgeInsets.all(16),
                child: SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator())),
              ),
              error: (e, _) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('加载失败: $e'),
                ),
              ),
            ),

            // ── Recent transactions (grouped by date) ─────────
            monthTxsAsync.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: '本月还没有账单，点右下角记一笔吧',
                  );
                }

                final cats = <int, Category>{};
                categoriesAsync.whenData((list) {
                  for (final c in list) {
                    cats[c.id!] = c;
                  }
                });
                final accs = <int, String>{};
                accountsAsync.whenData((list) {
                  for (final a in list) {
                    accs[a.id!] = a.name;
                  }
                });

                // Group by date.
                final grouped = <String, List<Transaction>>{};
                for (final t in txns) {
                  final key = DateFormat('yyyy-MM-dd').format(t.date);
                  grouped.putIfAbsent(key, () => []).add(t);
                }
                final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                return Column(
                  children: dates.map((date) {
                    final dayTxns = grouped[date]!;
                    final isToday = date == DateFormat('yyyy-MM-dd').format(DateTime.now());
                    return Column(
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                isToday ? '今天' : date,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isToday ? '' : ''}${dayTxns.length}笔',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Transactions for this date
                        ...dayTxns.map((t) {
                          final cat = cats[t.categoryId];
                          final acc = accs[t.accountId] ?? '未知';
                          return TransactionTile(
                            transaction: t,
                            category: cat ?? Category(
                                  name: '未分类',
                                  iconName: 'help_outline',
                                  colorValue: 0xFF9E9E9E,
                                  type: t.type,
                                ),
                            accountName: acc,
                            onTap: () => _showTransactionDetail(
                              context, ref, t, cat, acc,
                            ),
                            onDelete: t.id != null
                                ? () => ref
                                    .read(transactionMutationsProvider)
                                    .delete(t.id!)
                                : null,
                          );
                        }),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  /// Bottom sheet with all ledgers and a "新建" action.
  void _showLedgerSwitcher(
    BuildContext context,
    WidgetRef ref,
    Ledger current,
    AsyncValue<List<Ledger>> allLedgersAsync,
  ) {
    allLedgersAsync.whenData((ledgers) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('切换账本',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...ledgers.map((l) {
                final isCurrent = l.id == current.id;
                return ListTile(
                  leading: Icon(
                    _ledgerIcon(l.iconName),
                    color: Color(l.colorValue),
                  ),
                  title: Text(l.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent)
                        Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary),
                      if (ledgers.length > 1)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () => _deleteLedger(
                              context, ref, l, ledgers),
                        ),
                    ],
                  ),
                  onTap: () {
                    ref
                        .read(currentLedgerIdProvider.notifier)
                        .state = l.id!;
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('新建账本'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateLedger(context, ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  void _showCreateLedger(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateLedgerSheet(),
    );
  }

  void _deleteLedger(
    BuildContext context,
    WidgetRef ref,
    Ledger ledger,
    List<Ledger> allLedgers,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账本'),
        content: Text(
            '确定删除账本"${ledger.name}"吗？\n\n该账本下的所有账单记录也会一并删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              ref.read(ledgerMutationsProvider).delete(ledger.id!);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
    Category? cat,
    String accountName,
  ) {
    final isExpense = t.isExpense;
    final category = cat ?? Category(
      name: '未分类',
      iconName: 'help_outline',
      colorValue: 0xFF9E9E9E,
      type: t.type,
    );
    final symbol = _currencySymbols[t.currencyCode] ?? t.currencyCode;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Category icon + name
              CircleAvatar(
                radius: 32,
                backgroundColor: category.color.withValues(alpha: 0.15),
                child: Icon(category.icon, color: category.color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(category.name, style: theme.textTheme.titleMedium),

              // Amount (original currency)
              const SizedBox(height: 12),
              Text(
                '${isExpense ? '-' : '+'}$symbol${NumberFormat.currency(symbol: '', decimalDigits: 2).format(t.amount)}',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExpense
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),

              // Details
              _detailRow(theme, '类型', isExpense ? '支出' : '收入'),
              _detailRow(theme, '账户', accountName),
              _detailRow(theme, '币种', t.currencyCode),
              if (t.exchangeRate != null)
                _detailRow(theme, '汇率', t.exchangeRate!.toStringAsFixed(4)),
              _detailRow(theme, '日期', DateFormat('yyyy-MM-dd').format(t.date)),
              if (t.note != null && t.note!.isNotEmpty)
                _detailRow(theme, '备注', t.note!),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showAddSheet(context, ref, transaction: t);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmAndDelete(context, ref, t, category.name);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
    String categoryName,
  ) async {
    final isExpense = t.isExpense;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: Text(
            '确定删除 "$categoryName" ${isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && t.id != null) {
      ref.read(transactionMutationsProvider).delete(t.id!);
    }
  }

  void _showAddSheet(BuildContext context, WidgetRef ref,
      {Transaction? transaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          AddTransactionSheet(transaction: transaction),
    );
  }
}

IconData _ledgerIcon(String name) {
  switch (name) {
    case 'book':
      return Icons.book;
    case 'wallet':
      return Icons.account_balance_wallet;
    case 'flight':
      return Icons.flight;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'business':
      return Icons.business;
    default:
      return Icons.book;
  }
}
