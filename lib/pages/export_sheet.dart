import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ledger.dart';
import '../models/transaction.dart';
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
  final Set<int> _selectedLedgerIds = {};

  Future<void> _export() async {
    if (_selectedLedgerIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一个账本')),
        );
      }
      return;
    }

    setState(() => _exporting = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final allTransactions = <Transaction>[];

      for (final ledgerId in _selectedLedgerIds) {
        final txs = await repo.getAll(ledgerId: ledgerId);
        allTransactions.addAll(txs);
      }

      if (allTransactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('所选账本没有可导出的账单')),
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
        transactions: allTransactions,
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

  void _toggleAll(List<Ledger> ledgers) {
    setState(() {
      if (_selectedLedgerIds.length == ledgers.length) {
        _selectedLedgerIds.clear();
      } else {
        _selectedLedgerIds.addAll(ledgers.map((l) => l.id!));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(allLedgersProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle.
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

          // Title.
          Icon(Icons.file_download_outlined,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('导出账单',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '选择要导出的账本',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Ledger selection list.
          ledgerAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载账本失败: $err',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
            data: (ledgers) {
              // Init selection on first load.
              if (_selectedLedgerIds.isEmpty && ledgers.isNotEmpty) {
                _selectedLedgerIds.addAll(ledgers.map((l) => l.id!));
              }

              if (ledgers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无账本'),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Select All / Deselect All
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _toggleAll(ledgers),
                        icon: Icon(
                          _selectedLedgerIds.length == ledgers.length
                              ? Icons.deselect
                              : Icons.select_all,
                          size: 18,
                        ),
                        label: Text(
                          _selectedLedgerIds.length == ledgers.length
                              ? '取消全选'
                              : '全选',
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '已选 ${_selectedLedgerIds.length}/${ledgers.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),

                  // Ledger checkboxes.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: ledgers.length,
                      itemBuilder: (ctx, i) {
                        final ledger = ledgers[i];
                        final selected =
                            _selectedLedgerIds.contains(ledger.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedLedgerIds.add(ledger.id!);
                              } else {
                                _selectedLedgerIds.remove(ledger.id);
                              }
                            });
                          },
                          title: Text(ledger.name),
                          secondary: Icon(
                            Icons.book_outlined,
                            color: Color(ledger.colorValue),
                          ),
                          controlAffinity:
                              ListTileControlAffinity.trailing,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Export button.
          FilledButton.icon(
            onPressed: _exporting || _selectedLedgerIds.isEmpty
                ? null
                : _export,
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
