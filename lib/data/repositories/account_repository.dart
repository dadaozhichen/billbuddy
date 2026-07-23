import '../../models/account.dart';
import '../datasources/local_database.dart';

/// Repository for reading and writing [Account] records.
class AccountRepository {
  AccountRepository._();

  static final AccountRepository _instance = AccountRepository._();
  static AccountRepository get instance => _instance;

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// All accounts, ordered by [sortOrder].
  Future<List<Account>> getAll() async {
    final db = await LocalDatabase.database;
    final rows = await db.query('accounts', orderBy: 'sort_order');
    return rows.map(Account.fromMap).toList();
  }

  /// A single account by [id], or `null`.
  Future<Account?> getById(int id) async {
    final db = await LocalDatabase.database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  /// Insert a new account. Returns its generated id.
  Future<int> insert(Account account) async {
    final db = await LocalDatabase.database;
    return db.insert('accounts', account.toMap());
  }

  /// Update an existing account.
  Future<int> update(Account account) async {
    final db = await LocalDatabase.database;
    return db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Delete an account by [id].
  Future<int> delete(int id) async {
    final db = await LocalDatabase.database;
    return db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }
}
