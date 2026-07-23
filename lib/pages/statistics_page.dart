import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/stats_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/summary_card.dart';

/// Statistics page with period selector, pie chart, and trend bar chart.
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  StatsPeriod _period = StatsPeriod.thisMonth;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsProvider(_period));
    final trendAsync = ref.watch(monthlyTrendProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(refreshTriggerProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Period selector ──────────────────────────────
            _PeriodSelector(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 8),

            // ── Summary card ─────────────────────────────────
            statsAsync.when(
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
                  child: Text('$e'),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Category breakdown (side by side) ────────────
            statsAsync.when(
              data: (s) {
                final hasExpense = s.expenseBreakdown.isNotEmpty;
                final hasIncome = s.incomeBreakdown.isNotEmpty;
                if (!hasExpense && !hasIncome) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasExpense)
                        Expanded(
                          child: _CategoryPieChart(
                            title: '支出',
                            data: s.expenseBreakdown,
                            totalInCents: s.expenseInCents,
                          ),
                        ),
                      if (hasExpense && hasIncome)
                        const SizedBox(width: 12),
                      if (hasIncome)
                        Expanded(
                          child: _CategoryPieChart(
                            title: '收入',
                            data: s.incomeBreakdown,
                            totalInCents: s.incomeInCents,
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
            const SizedBox(height: 16),

            // ── Monthly trend (bar chart) ────────────────────
            trendAsync.when(
              data: (trend) {
                if (trend.isEmpty) return const SizedBox();
                return _TrendBarChart(data: trend);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period selector chips ─────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip('本月', StatsPeriod.thisMonth),
          const SizedBox(width: 8),
          _chip('上月', StatsPeriod.lastMonth),
          const SizedBox(width: 8),
          _chip('今年', StatsPeriod.thisYear),
        ],
      ),
    );
  }

  Widget _chip(String label, StatsPeriod value) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
    );
  }
}

// ── Pie chart ────────────────────────────────────────────────────

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({
    required this.title,
    required this.data,
    required this.totalInCents,
  });

  final String title;
  final List<CategoryExpense> data;
  final int totalInCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show top 5 + "其他"
    final items = data.length > 5 ? data.take(5).toList() : data;
    final others = data.length > 5
        ? data.skip(5).fold<int>(0, (sum, e) => sum + e.totalInCents)
        : 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    ...items.asMap().entries.map((e) =>
                        _section(e.value, e.key, items.length)),
                    if (others > 0)
                      PieChartSectionData(
                        value: others.toDouble(),
                        color: theme.colorScheme.outlineVariant,
                        title: '其他',
                        titleStyle: const TextStyle(fontSize: 9),
                        radius: 40,
                      ),
                  ],
                  centerSpaceRadius: 24,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PieLegend(items: items, total: totalInCents),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(
      CategoryExpense item, int index, int count) {
    final hue = (360.0 / count * index);
    final color = HSLColor.fromAHSL(1, hue, 0.6, 0.5).toColor();
    final pct = totalInCents > 0
        ? (item.totalInCents / totalInCents * 100).toStringAsFixed(0)
        : '0';
    return PieChartSectionData(
      value: item.totalInCents.toDouble(),
      color: color,
      title: '$pct%',
      titleStyle: const TextStyle(fontSize: 9, color: Colors.white),
      radius: 40,
    );
  }
}

class _PieLegend extends StatelessWidget {
  const _PieLegend({
    required this.items,
    required this.total,
  });

  final List<CategoryExpense> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((e) {
        final pct = total > 0 ? e.totalInCents / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: Color(e.category.colorValue)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(e.category.name,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Trend bar chart ──────────────────────────────────────────────

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.data});

  final List<(String, int, int)> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only show last 6 months for readability.
    final display = data.length > 6 ? data.sublist(data.length - 6) : data;

    if (display.isEmpty) return const SizedBox();

    final maxVal = display.fold<int>(
        0, (m, d) => [m, d.$2, d.$3].reduce((a, b) => a > b ? a : b));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度趋势（近 ${display.length} 个月）',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal < 1 ? 100 : maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) {
                        final i = group.x.toInt();
                        if (i >= display.length) return null;
                        final label = display[i].$1;
                        final expense = display[i].$2 / 100;
                        final income = display[i].$3 / 100;
                        return BarTooltipItem(
                          '$label\n支出: ¥${expense.toStringAsFixed(0)}\n收入: ¥${income.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) {
                          if (v == 0) return const SizedBox();
                          return Text('¥${(v / 100).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= display.length) {
                            return const SizedBox();
                          }
                          // Show short month label.
                          final parts = display[i].$1.split('-');
                          final label = parts.length == 2 ? parts[1] : '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal < 1 ? 25 : maxVal / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: display.asMap().entries.map((e) {
                    final i = e.key;
                    final (_, expense, income) = e.value;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: expense.toDouble(),
                        color: theme.colorScheme.error,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: income.toDouble(),
                        color: theme.colorScheme.primary,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(theme.colorScheme.error, '支出'),
                const SizedBox(width: 24),
                _legendDot(theme.colorScheme.primary, '收入'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
        )),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
