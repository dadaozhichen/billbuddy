import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/currency.dart';
import '../providers/currency_provider.dart';
import 'exchange_rate_page.dart';
import 'export_sheet.dart';
import 'import_preview_page.dart';

/// Settings: default currency, export, AI config, etc.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ── Currency ──────────────────────────────────────────
          const _SectionHeader(title: '币种'),
          ListTile(
            leading: const Icon(Icons.currency_yuan),
            title: const Text('默认币种'),
            subtitle: defaultCurrencyAsync.when(
              data: (c) => Text('${c.symbol} ${c.name} (${c.code})'),
              loading: () => const Text('加载中...'),
              error: (e, _) => Text('$e'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickDefaultCurrency(
              context,
              ref,
              defaultCurrencyAsync.valueOrNull,
              currenciesAsync.valueOrNull ?? [],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('汇率管理'),
            subtitle: const Text('设置各币种间的换算比例'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExchangeRatePage()),
            ),
          ),
          const Divider(),

          // ── Data ──────────────────────────────────────────────
          const _SectionHeader(title: '数据'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出为 Excel'),
            subtitle: const Text('备份或迁移数据'),
            onTap: () => showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const ExportSheet(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导入 Excel'),
            subtitle: const Text('从文件添加账单'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImportPreviewPage()),
            ),
          ),
          const Divider(),

          // ── AI ────────────────────────────────────────────────
          const _SectionHeader(title: '智能'),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 助手'),
            subtitle: const Text('自动分类 · 拍照记账'),
            onTap: () {}, // Phase 5
          ),
          const Divider(),

          // ── About ─────────────────────────────────────────────
          ListTile(
            leading: Icon(Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant),
            title: Text('版本',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  void _pickDefaultCurrency(
    BuildContext context,
    WidgetRef ref,
    CurrencyInfo? current,
    List<CurrencyInfo> currencies,
  ) {
    if (current == null || currencies.isEmpty) return;

    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择默认币种'),
        children: currencies
            .map((c) => ListTile(
                  leading: Icon(
                    c.code == current.code
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: c.code == current.code
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text('${c.symbol} ${c.name} (${c.code})'),
                  onTap: () => Navigator.of(ctx).pop(c.code),
                ))
            .toList(),
      ),
    ).then((selected) {
      if (selected != null && selected != current.code) {
        ref.read(currencyMutationsProvider).setDefaultCurrency(selected);
      }
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
