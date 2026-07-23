import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/currency.dart';
import '../providers/currency_provider.dart';
import '../services/update_service.dart';
import 'exchange_rate_page.dart';
import 'export_sheet.dart';
import 'import_preview_page.dart';

/// Settings: default currency, export, AI config, etc.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _VersionTile(),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: const Text('从 GitHub 获取最新版本'),
            onTap: () => _checkUpdate(context),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context) async {
    // Loading dialog.
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await UpdateService.check();

    // Close loading dialog.
    if (context.mounted) Navigator.of(context).pop();

    if (!context.mounted) return;

    if (result.checkFailed) {
      // Network / API error — let the user go to releases page manually.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('检查更新失败'),
          content: Text('无法连接到更新服务器。\n${result.error}\n\n请手动前往 Releases 页面查看。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                UpdateService.openUrl(UpdateService.releasesUrl);
                Navigator.of(ctx).pop();
              },
              child: const Text('前往 Releases'),
            ),
          ],
        ),
      );
      return;
    }

    if (!result.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('已是最新版本'),
          content: Text('当前版本 v${result.currentVersion} 已是最新'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      return;
    }

    // Update available.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：v${result.currentVersion}'),
            Text('最新版本：v${result.latestVersion}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (result.releaseNotes != null) ...[
              const SizedBox(height: 12),
              const Text('更新内容：',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(result.releaseNotes!,
                  style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              final url = result.releaseUrl ??
                  'https://github.com/dadaozhichen/billbuddy/releases';
              UpdateService.openUrl(url);
              Navigator.of(ctx).pop();
            },
            child: const Text('下载更新'),
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

/// Shows the current app version (loaded from package info).
class _VersionTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '加载中...';
        return ListTile(
          leading: Icon(Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant),
          title: Text('版本',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          subtitle: Text(version),
        );
      },
    );
  }
}
