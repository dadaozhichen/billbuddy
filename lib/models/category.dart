import 'package:flutter/material.dart';

/// The direction of a transaction's cash flow.
enum TransactionType { income, expense }

/// A spending or income category (e.g., 餐饮, 交通, 工资).
///
/// Each category belongs to either [TransactionType.income] or
/// [TransactionType.expense], carries a Material [icon] for the UI,
/// and a [color] used in charts and list tiles.
class Category {
  final int? id;
  final String name;
  final String iconName;
  final int colorValue;
  final TransactionType type;

  const Category({
    this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    required this.type,
  });

  /// Resolves [iconName] to a Material [IconData].
  IconData get icon => _iconMap[iconName] ?? Icons.help_outline;

  /// Material [Color] parsed from the stored [colorValue].
  Color get color => Color(colorValue);

  // -- helpers -----------------------------------------------------------

  /// Deserialise from a SQLite row.
  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        iconName: map['icon_name'] as String,
        colorValue: map['color_value'] as int,
        type: TransactionType.values.byName(map['type'] as String),
      );

  /// Serialise for SQLite.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_name': iconName,
        'color_value': colorValue,
        'type': type.name,
      };

  /// Produce a copy with any overridden fields.
  Category copyWith({
    int? id,
    String? name,
    String? iconName,
    int? colorValue,
    TransactionType? type,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        colorValue: colorValue ?? this.colorValue,
        type: type ?? this.type,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          iconName == other.iconName &&
          colorValue == other.colorValue &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, name, iconName, colorValue, type);
}

/// Maps category icon names to their Material [IconData], one per app icon.
const _iconMap = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_cart': Icons.shopping_cart,
  'home': Icons.home,
  'videogame_asset': Icons.videogame_asset,
  'local_hospital': Icons.local_hospital,
  'phone': Icons.phone,
  'school': Icons.school,
  'work': Icons.work,
  'laptop': Icons.laptop,
  'trending_up': Icons.trending_up,
  'credit_card': Icons.credit_card,
  'flight': Icons.flight,
  'fitness_center': Icons.fitness_center,
  'pets': Icons.pets,
  'help_outline': Icons.help_outline,
};
