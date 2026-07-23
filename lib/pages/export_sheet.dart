import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/excel_service.dart';

/// Bottom sheet for exporting transactions to .xlsx.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);

    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final repo = ref.read(transactionRepositoryProvider);
      final transactions = await repo.getAll(ledgerId: ledgerId);

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前账本没有可导出的账单')),
          );
        }
        return;
      }

      // Build category & account name maps.
      final catRepo = ref.read(categoryRepositoryProvider);
      final accRepo = ref.read(accountRepositoryProvider);
      final cats = await catRepo.getAll();
      final accs = await accRepo.getAll();
      final catNames = {for (final c in cats) c.id!: c.name};
      final accNames = {for (final a in accs) a.id!: a.name};

      final bytes = ExcelService.export(
        transactions: transactions,
        categoryNames: catNames,
        accountNames: accNames,
      );

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'billbuddy_$timestamp.xlsx';

      // Save to app documents directory (always writable, no sandbox issues).
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      final savedPath = file.path;

      if (!mounted) return;

      // Try sharing (works on mobile; macOS needs entitlements).
      try {
        await Share.shareXFiles([XFile(savedPath)]);
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        // Share failed, but file is saved — show the path.
        if (mounted) _showSavedDialog(context, savedPath);
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSavedDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件已保存到：'),
            const SizedBox(height: 8),
            Text(path, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(Icons.file_download_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('导出账单', style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '将当前账本的所有账单导出为 .xlsx 文件',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download),
            label: Text(_exporting ? '正在导出...' : '导出'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
