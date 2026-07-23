import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/currency.dart';
import '../providers/currency_provider.dart';

/// Page for viewing and editing exchange rates.
class ExchangeRatePage extends ConsumerWidget {
  const ExchangeRatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ratesAsync = ref.watch(allExchangeRatesProvider);
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('汇率管理')),
      body: ratesAsync.when(
        data: (rates) {
          if (rates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('还没有汇率数据',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角 + 添加汇率',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: rates.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) {
              final r = rates[i];
              final from = r['from_code'] as String;
              final to = r['to_code'] as String;
              final rate = r['rate'] as num;
              return ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.swap_horiz, size: 20)),
                title: Text('$from → $to',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('1 $from = $rate $to'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editRate(context, ref, from, to, rate.toDouble()),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addRate(context, ref, currenciesAsync.valueOrNull ?? []),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _editRate(
    BuildContext context,
    WidgetRef ref,
    String fromCode,
    String toCode,
    double currentRate,
  ) {
    final controller = TextEditingController(text: currentRate.toStringAsFixed(4));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑汇率'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1 $fromCode = ? $toCode'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '例如 7.24',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final rate = double.tryParse(controller.text);
              if (rate == null || rate <= 0) return;
              ref
                  .read(currencyMutationsProvider)
                  .setRate(fromCode, toCode, rate);
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _addRate(
    BuildContext context,
    WidgetRef ref,
    List<CurrencyInfo> currencies,
  ) {
    String? fromCode;
    String? toCode;
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加汇率'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // From currency
              DropdownButtonFormField<String>(
                initialValue: fromCode,
                decoration: const InputDecoration(
                  labelText: '源币种',
                  border: OutlineInputBorder(),
                ),
                items: currencies
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.symbol} ${c.code} - ${c.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => fromCode = v),
              ),
              const SizedBox(height: 12),

              // To currency
              DropdownButtonFormField<String>(
                initialValue: toCode,
                decoration: const InputDecoration(
                  labelText: '目标币种',
                  border: OutlineInputBorder(),
                ),
                items: currencies
                    .where((c) => c.code != fromCode)
                    .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.symbol} ${c.code} - ${c.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => toCode = v),
              ),
              const SizedBox(height: 12),

              // Rate
              if (fromCode != null && toCode != null)
                Text('1 $fromCode = ? $toCode',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '例如 7.24',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (fromCode == null || toCode == null) return;
                if (fromCode == toCode) return;
                final rate = double.tryParse(rateController.text);
                if (rate == null || rate <= 0) return;
                ref
                    .read(currencyMutationsProvider)
                    .setRate(fromCode!, toCode!, rate);
                Navigator.of(ctx).pop();
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
