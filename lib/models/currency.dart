/// ISO-4217 currency definition.
class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    this.decimalPlaces = 2,
  });

  // -- helpers -----------------------------------------------------------

  factory CurrencyInfo.fromMap(Map<String, dynamic> map) => CurrencyInfo(
        code: map['code'] as String,
        name: map['name'] as String,
        symbol: map['symbol'] as String,
        decimalPlaces: map['decimal_places'] as int? ?? 2,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'symbol': symbol,
        'decimal_places': decimalPlaces,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyInfo &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$symbol$code';
}
