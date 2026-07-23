import '../../models/ledger.dart';
import '../datasources/local_database.dart';

/// Repository for reading and writing [Ledger] records.
class LedgerRepository {
  LedgerRepository._();

  static final LedgerRepository _instance = LedgerRepository._();
  static LedgerRepository get instance => _instance;

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// All ledgers, ordered by [sortOrder].
  Future<List<Ledger>> getAll() async {
    final db = await LocalDatabase.database;
    final rows = await db.query('ledgers', orderBy: 'sort_order');
    return rows.map(Ledger.fromMap).toList();
  }

  /// A single ledger by [id], or `null`.
  Future<Ledger?> getById(int id) async {
    final db = await LocalDatabase.database;
    final rows = await db.query('ledgers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Ledger.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  /// Insert a new ledger. Returns its generated id.
  Future<int> insert(Ledger ledger) async {
    final db = await LocalDatabase.database;
    return db.insert('ledgers', ledger.toMap());
  }

  /// Update an existing ledger.
  Future<int> update(Ledger ledger) async {
    final db = await LocalDatabase.database;
    return db.update(
      'ledgers',
      ledger.toMap(),
      where: 'id = ?',
      whereArgs: [ledger.id],
    );
  }

  /// Delete a ledger by [id]. Returns the number of rows affected.
  Future<int> delete(int id) async {
    final db = await LocalDatabase.database;
    return db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }
}
