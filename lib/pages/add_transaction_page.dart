import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/currency.dart';
import '../models/transaction.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/transaction_provider.dart';

/// Modal bottom sheet for recording a single transaction.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  TransactionType _type = TransactionType.expense;
  int _amountInCents = 0;
  int? _categoryId;
  int? _accountId;
  final _noteController = TextEditingController();
  final _rateController = TextEditingController();
  CurrencyInfo _selectedCurrency =
      const CurrencyInfo(code: 'CNY', name: '人民币', symbol: '¥');
  double? _exchangeRate;
  bool _saving = false;
  bool _rateInitialised = false;

  @override
  void dispose() {
    _noteController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _amountInCents > 0 && _categoryId != null && _accountId != null;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);

    try {
      final defaultCode =
          await ref.read(defaultCurrencyProvider.future).then((c) => c.code);
      final isBase = _selectedCurrency.code == defaultCode;

      await ref.read(transactionMutationsProvider).add(
            Transaction(
              amountInCents: _amountInCents,
              ledgerId: ref.read(currentLedgerIdProvider),
              currencyCode: _selectedCurrency.code,
              exchangeRate: isBase ? null : _exchangeRate,
              baseCurrencyCode: defaultCode,
              type: _type,
              categoryId: _categoryId!,
              accountId: _accountId!,
              date: DateTime.now(),
              note:
                  _noteController.text.isEmpty ? null : _noteController.text,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Called once when the currency changes to auto-fill the stored rate.
  void _maybeAutoFillRate(String code, String defaultCode) {
    if (_rateInitialised) return;
    if (code == defaultCode) return;
    ref.read(currencyRepositoryProvider).getRate(code, defaultCode).then((r) {
      if (r != null && mounted) {
        _rateController.text = r.toStringAsFixed(4);
        setState(() => _exchangeRate = r);
      }
    });
    _rateInitialised = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(
      _type == TransactionType.expense
          ? expenseCategoriesProvider
          : incomeCategoriesProvider,
    );
    final accountsAsync = ref.watch(accountsProvider);
    final currenciesAsync = ref.watch(allCurrenciesProvider);
    final defaultCurrencyAsync = ref.watch(defaultCurrencyProvider);
    final defaultCurrency =
        defaultCurrencyAsync.valueOrNull ?? _selectedCurrency;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ─────────────────────────────────────────
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

            // ── Type toggle ────────────────────────────────────
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.expense, label: Text('支出')),
                ButtonSegment(
                    value: TransactionType.income, label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
            const SizedBox(height: 20),

            // ── Amount + Currency picker ───────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: InputDecoration(
                      prefixText: '${_selectedCurrency.symbol} ',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    onChanged: (v) {
                      final amount = double.tryParse(v) ?? 0;
                      setState(
                          () => _amountInCents = (amount * 100).round());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // ── Currency dropdown ─────────────────────────
                currenciesAsync.when(
                  data: (currencies) => DropdownButton<String>(
                    value: _selectedCurrency.code,
                    underline: const SizedBox(),
                    items: currencies
                        .map((c) => DropdownMenuItem(
                              value: c.code,
                              child: Text('${c.symbol} ${c.code}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                    onChanged: (code) {
                      if (code == null) return;
                      final picked =
                          currencies.firstWhere((c) => c.code == code);
                      _rateInitialised = false;
                      setState(() => _selectedCurrency = picked);
                      _maybeAutoFillRate(code, defaultCurrency.code);
                    },
                  ),
                  loading: () => const SizedBox(
                      width: 48,
                      height: 24,
                      child: Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, _) => const Text('CNY'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Exchange rate (shown for non-base currencies) ──
            if (_selectedCurrency.code != defaultCurrency.code) ...[
              TextField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText:
                      '汇率 (1 ${_selectedCurrency.code} = ? ${defaultCurrency.code})',
                  hintText: '例如 7.24',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() => _exchangeRate = double.tryParse(v));
                },
              ),
              const SizedBox(height: 20),
            ],

            // ── Category grid ──────────────────────────────────
            Text('分类', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (cats) => SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _CategoryChip(
                    category: cats[i],
                    selected: _categoryId == cats[i].id,
                    onTap: () => setState(() => _categoryId = cats[i].id),
                  ),
                ),
              ),
              loading: () => const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('加载失败: $e'),
            ),
            const SizedBox(height: 16),

            // ── Account chips ──────────────────────────────────
            Text('账户', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) => Wrap(
                spacing: 8,
                children: accounts
                    .map((a) => ChoiceChip(
                          label: Text(a.name),
                          selected: _accountId == a.id,
                          onSelected: (_) =>
                              setState(() => _accountId = a.id),
                        ))
                    .toList(),
              ),
              loading: () => const SizedBox(),
              error: (e, _) => Text('加载失败: $e'),
            ),
            const SizedBox(height: 16),

            // ── Note ───────────────────────────────────────────
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: '备注（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 20),

            // ── Save ───────────────────────────────────────────
            FilledButton(
              onPressed: _valid && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable icon for selecting a transaction category.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: category.color, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              color: selected
                  ? category.color
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? category.color
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
