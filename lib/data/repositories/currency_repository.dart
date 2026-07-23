import 'package:sqflite/sqflite.dart';

import '../../models/currency.dart';
import '../datasources/local_database.dart';

/// Repository for reading and writing currencies, exchange rates,
/// and user preferences (default currency).
class CurrencyRepository {
  CurrencyRepository._();

  static final CurrencyRepository _instance = CurrencyRepository._();
  static CurrencyRepository get instance => _instance;

  // ------------------------------------------------------------------
  // Currencies
  // ------------------------------------------------------------------

  /// Every supported currency, ordered by code.
  Future<List<CurrencyInfo>> getAllCurrencies() async {
    final db = await LocalDatabase.database;
    final rows = await db.query('currencies', orderBy: 'code');
    return rows.map(CurrencyInfo.fromMap).toList();
  }

  /// A single currency by [code], or `null`.
  Future<CurrencyInfo?> getCurrency(String code) async {
    final db = await LocalDatabase.database;
    final rows =
        await db.query('currencies', where: 'code = ?', whereArgs: [code]);
    return rows.isEmpty ? null : CurrencyInfo.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // Exchange Rates
  // ------------------------------------------------------------------

  /// The stored rate from [fromCode] to [toCode], or `null`.
  Future<double?> getRate(String fromCode, String toCode) async {
    final db = await LocalDatabase.database;
    final rows = await db.query(
      'exchange_rates',
      where: 'from_code = ? AND to_code = ?',
      whereArgs: [fromCode, toCode],
    );
    return rows.isEmpty ? null : (rows.first['rate'] as num).toDouble();
  }

  /// Upsert an exchange rate.
  Future<void> setRate(
    String fromCode,
    String toCode,
    double rate,
  ) async {
    final db = await LocalDatabase.database;
    await db.insert(
      'exchange_rates',
      {
        'from_code': fromCode,
        'to_code': toCode,
        'rate': rate,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All stored exchange rates.
  Future<List<Map<String, dynamic>>> getAllRates() async {
    final db = await LocalDatabase.database;
    return db.query('exchange_rates', orderBy: 'from_code, to_code');
  }

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------

  /// The user's default currency code (e.g. "CNY").
  Future<String> getDefaultCurrencyCode() async {
    final db = await LocalDatabase.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['default_currency'],
    );
    if (rows.isEmpty) return 'CNY';
    return rows.first['value'] as String;
  }

  /// Persist the user's default currency.
  Future<void> setDefaultCurrencyCode(String code) async {
    final db = await LocalDatabase.database;
    await db.insert(
      'settings',
      {'key': 'default_currency', 'value': code},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
