import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';

/// Common currency symbols for display when a transaction uses
/// a non-default currency.
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

/// A single transaction row used in list views.
///
/// Pass an [onDelete] callback to enable left-swipe deletion.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.accountName,
    this.onTap,
    this.onDelete,
  });

  final Transaction transaction;
  final Category category;
  final String accountName;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = transaction.isExpense;
    final symbol = _currencySymbols[transaction.currencyCode] ??
        transaction.currencyCode;

    return Dismissible(
      key: ValueKey('tx_${transaction.id}'),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除账单'),
            content: Text(
                '确定删除 "${category.name}" ${isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)} 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.15),
          child: Icon(category.icon, color: category.color, size: 20),
        ),
        title: Text(category.name),
        subtitle: Text(
          accountName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isExpense ? '-' : '+'}$symbol${NumberFormat.currency(symbol: '', decimalDigits: 2).format(transaction.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExpense
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (!transaction.isBaseCurrency)
              Text(
                '→ ${transaction.baseCurrencyCode}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
