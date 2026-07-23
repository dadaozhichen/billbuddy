import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/currency_provider.dart';

/// Page for viewing and editing exchange rates.
class ExchangeRatePage extends ConsumerWidget {
  const ExchangeRatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ratesAsync = ref.watch(allExchangeRatesProvider);

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
                    '记账时选择非默认币种会自动保存汇率',
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
              return ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.swap_horiz, size: 20)),
                title: Text(
                    '${r['from_code']} → ${r['to_code']}'),
                subtitle: Text('1 ${r['from_code']} = ${r['rate']} ${r['to_code']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editRate(context, ref,
                      r['from_code'] as String, r['to_code'] as String),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _editRate(
    BuildContext context,
    WidgetRef ref,
    String fromCode,
    String toCode,
  ) {
    final controller = TextEditingController();
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
}
