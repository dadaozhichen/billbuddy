/// A wallet or payment method (e.g., 微信, 支付宝, 现金).
class Account {
  final int? id;
  final String name;
  final int sortOrder;

  const Account({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  // -- helpers -----------------------------------------------------------

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as int?,
        name: map['name'] as String,
        sortOrder: map['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort_order': sortOrder,
      };

  Account copyWith({int? id, String? name, int? sortOrder}) => Account(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
