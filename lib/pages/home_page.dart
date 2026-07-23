import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/ledger.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';
import 'create_ledger_sheet.dart';

/// Main tab showing today's transactions and month summary.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthSummaryProvider);
    final todayAsync = ref.watch(todayTransactionsProvider);
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

            // ── Section header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '今日账单',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

            // ── Today's transactions ─────────────────────────
            todayAsync.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: '今天还没有账单，点右下角记一笔吧',
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

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txns.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final t = txns[i];
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
                      onDelete: t.id != null
                          ? () => ref
                              .read(transactionMutationsProvider)
                              .delete(t.id!)
                          : null,
                    );
                  },
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

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddTransactionSheet(),
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
