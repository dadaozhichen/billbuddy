import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/excel_row.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/excel_service.dart';
import '../services/import_processor.dart';

/// Import flow: pick file → preview → confirm.
class ImportPreviewPage extends ConsumerStatefulWidget {
  const ImportPreviewPage({super.key});

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage> {
  bool _loading = false;
  bool _importing = false;
  ImportResult? _result;
  ProcessedImport? _processed;
  final _pathController = TextEditingController();
  String? _lastError;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  // ── File picker ─────────────────────────────────────────────────

  /// Uses Flutter's official [openFile] — works on macOS, Linux, Windows.
  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: 'Excel 文件',
      extensions: ['xlsx'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return; // user cancelled
    await _parseFile(File(file.path));
  }

  // ── Manual path ────────────────────────────────────────────────

  Future<void> _parseFromPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
      _showError('文件不存在: $path');
      return;
    }

    setState(() {
      _loading = true;
      _lastError = null;
    });

    try {
      await _parseFile(file);
    } catch (e) {
      _showError('解析失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Parse & preview ───────────────────────────────────────────

  Future<void> _parseFile(File file) async {
    final bytes = await file.readAsBytes();
    final result = ExcelService.parse(bytes);

    final cats = await ref.read(categoryRepositoryProvider).getAll();
    final accs = await ref.read(accountRepositoryProvider).getAll();
    final accMap = {for (final a in accs) a.id!: a.name};
    final defaultCurrency = await ref.read(defaultCurrencyProvider.future);
    final ledgerId = ref.read(currentLedgerIdProvider);

    final processed = ImportProcessor.process(
      rows: result.rows,
      categories: cats,
      accounts: accMap,
      defaultCurrencyCode: defaultCurrency.code,
      ledgerId: ledgerId,
    );

    setState(() {
      _result = result;
      _processed = processed;
    });
  }

  Future<void> _confirmImport() async {
    final processed = _processed;
    if (processed == null || processed.transactions.isEmpty) return;

    setState(() => _importing = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      for (final t in processed.transactions) {
        await repo.insert(t);
      }
      ref.read(refreshTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${processed.validCount} 条账单')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _processed = null;
      _lastError = null;
    });
  }

  void _showError(String msg) {
    setState(() => _lastError = msg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入账单'),
        actions: _result != null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新选择',
                  onPressed: _reset,
                ),
              ]
            : null,
      ),
      body: _result == null ? _buildPicker(theme) : _buildPreview(theme),
    );
  }

  Widget _buildPicker(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.file_upload_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('选择 .xlsx 文件导入',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '文件格式：日期 | 类型 | 金额 | 币种 | 分类 | 账户 | 备注',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ── File picker button ───────────────────────────
          FilledButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.folder_open),
            label: Text(_loading ? '解析中...' : '选择文件'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 24),

          // ── Error message ───────────────────────────────
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_lastError!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),

          // ── Divider ─────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('或手动输入路径',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          // ── Manual path input ───────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    hintText: '/Users/xxx/账单.xlsx',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _parseFromPath,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final processed = _processed!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Stat(label: '有效', value: '${processed.validCount}',
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 24),
                  _Stat(label: '错误', value: '${processed.errorCount}',
                      color: theme.colorScheme.error),
                  const Spacer(),
                  if (processed.errorCount > 0)
                    TextButton(
                      onPressed: () => _showErrors(context, processed.errors),
                      child: const Text('查看详情'),
                    ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: processed.transactions.isEmpty
              ? Center(
                  child: Text('没有可导入的数据',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.separated(
                  itemCount: processed.transactions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final t = processed.transactions[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.isExpense
                            ? theme.colorScheme.error.withValues(alpha: 0.15)
                            : theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(
                          t.isExpense
                              ? Icons.trending_down
                              : Icons.trending_up,
                          color: t.isExpense
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                          '${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}'),
                      subtitle: Text(
                        '${t.date.toIso8601String().substring(0, 10)} · ${t.currencyCode}',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: processed.transactions.isEmpty || _importing
                  ? null
                  : _confirmImport,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('确认导入 ${processed.validCount} 条'),
            ),
          ),
        ),
      ],
    );
  }

  void _showErrors(BuildContext context, List<ImportError> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入错误'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: errors.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: Text('${errors[i].rowNumber}',
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
              title: Text(errors[i].message,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
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
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
