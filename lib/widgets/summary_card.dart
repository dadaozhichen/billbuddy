import 'package:flutter/material.dart';

/// Displays income, expense, and net balance for a period.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.expenseFormatted,
    required this.incomeFormatted,
    required this.balanceFormatted,
    this.expenseInCents = 0,
    this.incomeInCents = 0,
  });

  final String expenseFormatted;
  final String incomeFormatted;
  final String balanceFormatted;
  final int expenseInCents;
  final int incomeInCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = expenseInCents + incomeInCents;
    final expenseRatio = total > 0 ? expenseInCents / total : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Text('本月收支', style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            const SizedBox(height: 12),
            // Balance
            Text(
              balanceFormatted,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: balanceFormatted.startsWith('-')
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Income / Expense bars
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (expenseRatio > 0)
                        Flexible(
                          flex: expenseInCents,
                          child: Container(color: theme.colorScheme.error),
                        ),
                      if (expenseRatio < 1)
                        Flexible(
                          flex: incomeInCents,
                          child: Container(color: theme.colorScheme.primary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Row: Income | Expense
            Row(
              children: [
                Expanded(
                  child: _LabeledAmount(
                    label: '支出',
                    amount: expenseFormatted,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _LabeledAmount(
                    label: '收入',
                    amount: incomeFormatted,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledAmount extends StatelessWidget {
  const _LabeledAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 4),
        Text(
          amount,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
