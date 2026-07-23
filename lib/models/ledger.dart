/// A named book that groups related transactions together.
///
/// Examples: 个人账本, 旅行账本, 生意账本.
/// Each ledger can optionally override the default currency.
class Ledger {
  final int? id;
  final String name;
  final String iconName;
  final int colorValue;
  final String? defaultCurrency;
  final int sortOrder;
  final DateTime createdAt;

  Ledger({
    this.id,
    required this.name,
    this.iconName = 'book',
    this.colorValue = 0xFF2E7D32,
    this.defaultCurrency,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // -- helpers -----------------------------------------------------------

  factory Ledger.fromMap(Map<String, dynamic> map) => Ledger(
        id: map['id'] as int?,
        name: map['name'] as String,
        iconName: map['icon_name'] as String? ?? 'book',
        colorValue: map['color_value'] as int? ?? 0xFF2E7D32,
        defaultCurrency: map['default_currency'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_name': iconName,
        'color_value': colorValue,
        if (defaultCurrency != null) 'default_currency': defaultCurrency,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  Ledger copyWith({
    int? id,
    String? name,
    String? iconName,
    int? colorValue,
    String? defaultCurrency,
    int? sortOrder,
    DateTime? createdAt,
  }) =>
      Ledger(
        id: id ?? this.id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        colorValue: colorValue ?? this.colorValue,
        defaultCurrency: defaultCurrency ?? this.defaultCurrency,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ledger &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
