import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ledger.dart';
import '../providers/ledger_provider.dart';

/// Bottom sheet for creating a new ledger.
class CreateLedgerSheet extends ConsumerStatefulWidget {
  const CreateLedgerSheet({super.key});

  @override
  ConsumerState<CreateLedgerSheet> createState() => _CreateLedgerSheetState();
}

class _CreateLedgerSheetState extends ConsumerState<CreateLedgerSheet> {
  final _nameController = TextEditingController();
  String _iconName = 'book';
  int _colorValue = 0xFF2E7D32;
  bool _saving = false;

  static const _icons = [
    ('book', Icons.book),
    ('wallet', Icons.account_balance_wallet),
    ('flight', Icons.flight),
    ('shopping_cart', Icons.shopping_cart),
    ('business', Icons.business),
    ('home', Icons.home),
    ('credit_card', Icons.credit_card),
    ('favorite', Icons.favorite),
  ];

  static const _colors = [
    ('绿色', 0xFF2E7D32),
    ('蓝色', 0xFF1565C0),
    ('橙色', 0xFFE65100),
    ('紫色', 0xFF6A1B9A),
    ('红色', 0xFFC62828),
    ('青色', 0xFF00838F),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    try {
      await ref.read(ledgerMutationsProvider).create(
            Ledger(
              name: name,
              iconName: _iconName,
              colorValue: _colorValue,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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
          Text('新建账本',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Name
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '账本名称',
              hintText: '例如：旅行账本',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon picker
          Text('图标', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _icons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (name, icon) = _icons[i];
                final selected = _iconName == name;
                return GestureDetector(
                  onTap: () => setState(() => _iconName = name),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(icon,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map(((String, int) c) {
              final (_, colorValue) = c;
              final selected = _colorValue == colorValue;
              return GestureDetector(
                onTap: () => setState(() => _colorValue = colorValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(colorValue),
                    borderRadius: BorderRadius.circular(18),
                    border: selected
                        ? Border.all(
                            color: theme.colorScheme.onSurface, width: 3)
                        : null,
                  ),
                  child: selected
                      ? Icon(Icons.check,
                          color: theme.colorScheme.onPrimary, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Save
          FilledButton(
            onPressed: _nameController.text.trim().isNotEmpty && !_saving
                ? _save
                : null,
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
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('创建', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
