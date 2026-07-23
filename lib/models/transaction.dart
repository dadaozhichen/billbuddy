import 'category.dart';

/// A single financial record — one inflow or outflow at a point in time.
///
/// All monetary amounts are stored as **cents** (integers) to avoid
/// floating-point drift. Use [amountInCents] for storage and [amount]
/// (which divides by 100) for display.
///
/// For multi-currency support, each transaction records its original
/// [currencyCode] and the [exchangeRate] to the user's
/// [baseCurrencyCode] at the time of entry so historical summaries
/// remain stable.
class Transaction {
  final int? id;
  final int ledgerId;
  final int amountInCents;
  final String currencyCode;
  final double? exchangeRate;
  final String baseCurrencyCode;
  final TransactionType type;
  final int categoryId;
  final int accountId;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  Transaction({
    this.id,
    this.ledgerId = 1,
    required this.amountInCents,
    this.currencyCode = 'CNY',
    this.exchangeRate,
    this.baseCurrencyCode = 'CNY',
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.date,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Display-friendly original amount (e.g., 1280 → 12.80).
  double get amount => amountInCents / 100.0;

  /// Whether this transaction is in the user's base currency.
  bool get isBaseCurrency => currencyCode == baseCurrencyCode;

  /// Amount converted to the base currency, or original if already base.
  double get baseAmount {
    if (isBaseCurrency || exchangeRate == null) return amount;
    return amount * exchangeRate!;
  }

  /// Whether this transaction represents money coming in.
  bool get isIncome => type == TransactionType.income;

  /// Whether this transaction represents money going out.
  bool get isExpense => type == TransactionType.expense;

  // -- helpers -----------------------------------------------------------

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as int?,
        ledgerId: map['ledger_id'] as int? ?? 1,
        amountInCents: map['amount_in_cents'] as int,
        currencyCode: map['currency_code'] as String? ?? 'CNY',
        exchangeRate: (map['exchange_rate'] as num?)?.toDouble(),
        baseCurrencyCode: map['base_currency_code'] as String? ?? 'CNY',
        type: TransactionType.values.byName(map['type'] as String),
        categoryId: map['category_id'] as int,
        accountId: map['account_id'] as int,
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ledger_id': ledgerId,
        'amount_in_cents': amountInCents,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'base_currency_code': baseCurrencyCode,
        'type': type.name,
        'category_id': categoryId,
        'account_id': accountId,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  Transaction copyWith({
    int? id,
    int? ledgerId,
    int? amountInCents,
    String? currencyCode,
    double? exchangeRate,
    String? baseCurrencyCode,
    TransactionType? type,
    int? categoryId,
    int? accountId,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) =>
      Transaction(
        id: id ?? this.id,
        ledgerId: ledgerId ?? this.ledgerId,
        amountInCents: amountInCents ?? this.amountInCents,
        currencyCode: currencyCode ?? this.currencyCode,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
        type: type ?? this.type,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        date: date ?? this.date,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
