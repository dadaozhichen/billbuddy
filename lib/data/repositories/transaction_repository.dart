import '../../models/transaction.dart';
import '../datasources/local_database.dart';

/// Repository for reading and writing [Transaction] records.
///
/// Expensive aggregations (monthly summaries, category breakdowns) are
/// computed here via SQL so the Dart layer never loads full datasets.
/// Every query accepts an optional [ledgerId] to filter by book.
class TransactionRepository {
  TransactionRepository._();

  static final TransactionRepository _instance = TransactionRepository._();
  static TransactionRepository get instance => _instance;

  /// Build a where clause fragment for ledger filtering.
  static String? _ledgerClause(int? ledgerId) =>
      ledgerId != null ? 'ledger_id = $ledgerId' : null;

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// All transactions, newest first. Optionally filtered by [ledgerId].
  Future<List<Transaction>> getAll({int? ledgerId}) async {
    final db = await LocalDatabase.database;
    final rows = await db.query(
      'transactions',
      where: _ledgerClause(ledgerId),
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Transactions within [range], newest first.
  Future<List<Transaction>> getByDateRange(
    DateTime start,
    DateTime end, {
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final conditions = <String>['date >= ?', 'date <= ?'];
    if (ledgerId != null) conditions.add('ledger_id = ?');
    final args = [start.toIso8601String(), end.toIso8601String()];
    if (ledgerId != null) args.add(ledgerId.toString());

    final rows = await db.query(
      'transactions',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// Today's transactions.
  Future<List<Transaction>> getToday({int? ledgerId}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getByDateRange(start, end, ledgerId: ledgerId);
  }

  /// A single transaction by [id], or `null`.
  Future<Transaction?> getById(int id) async {
    final db = await LocalDatabase.database;
    final rows =
        await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Transaction.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // Aggregations
  // ------------------------------------------------------------------

  /// Total expense (in cents) for the given [range].
  Future<int> totalExpenseInRange(
    DateTime start,
    DateTime end, {
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final conditions = <String>["type = 'expense'", 'date >= ?', 'date <= ?'];
    final args = [start.toIso8601String(), end.toIso8601String()];
    if (ledgerId != null) {
      conditions.add('ledger_id = ?');
      args.add(ledgerId.toString());
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_in_cents), 0) AS total'
      ' FROM transactions WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Total income (in cents) for the given [range].
  Future<int> totalIncomeInRange(
    DateTime start,
    DateTime end, {
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final conditions = <String>["type = 'income'", 'date >= ?', 'date <= ?'];
    final args = [start.toIso8601String(), end.toIso8601String()];
    if (ledgerId != null) {
      conditions.add('ledger_id = ?');
      args.add(ledgerId.toString());
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_in_cents), 0) AS total'
      ' FROM transactions WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Expense subtotal per category for the given [range].
  Future<List<(int, int)>> expenseByCategory(
    DateTime start,
    DateTime end, {
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final conditions = <String>["type = 'expense'", 'date >= ?', 'date <= ?'];
    final args = [start.toIso8601String(), end.toIso8601String()];
    if (ledgerId != null) {
      conditions.add('ledger_id = ?');
      args.add(ledgerId.toString());
    }
    final rows = await db.rawQuery(
      'SELECT category_id, SUM(amount_in_cents) AS total'
      ' FROM transactions WHERE ${conditions.join(' AND ')}'
      ' GROUP BY category_id ORDER BY total DESC',
      args,
    );
    return rows
        .map((r) => (r['category_id'] as int, (r['total'] as int?) ?? 0))
        .toList();
  }

  /// Income subtotal per category for the given [range].
  Future<List<(int, int)>> incomeByCategory(
    DateTime start,
    DateTime end, {
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final conditions = <String>["type = 'income'", 'date >= ?', 'date <= ?'];
    final args = [start.toIso8601String(), end.toIso8601String()];
    if (ledgerId != null) {
      conditions.add('ledger_id = ?');
      args.add(ledgerId.toString());
    }
    final rows = await db.rawQuery(
      'SELECT category_id, SUM(amount_in_cents) AS total'
      ' FROM transactions WHERE ${conditions.join(' AND ')}'
      ' GROUP BY category_id ORDER BY total DESC',
      args,
    );
    return rows
        .map((r) => (r['category_id'] as int, (r['total'] as int?) ?? 0))
        .toList();
  }

  /// Monthly expense & income totals for the last [months].
  ///
  /// Returns tuples of `(yearMonth, expenseInCents, incomeInCents)`.
  Future<List<(String, int, int)>> monthlyBreakdown({
    int months = 12,
    int? ledgerId,
  }) async {
    final db = await LocalDatabase.database;
    final start =
        DateTime(DateTime.now().year, DateTime.now().month - months + 1, 1);
    final conditions = <String>['date >= ?'];
    final args = <String>[start.toIso8601String()];
    if (ledgerId != null) {
      conditions.add('ledger_id = ?');
      args.add(ledgerId.toString());
    }

    final rows = await db.rawQuery(
      '''SELECT strftime('%Y-%m', date) AS month,
               COALESCE(SUM(CASE WHEN type='expense' THEN amount_in_cents ELSE 0 END), 0) AS expense,
               COALESCE(SUM(CASE WHEN type='income' THEN amount_in_cents ELSE 0 END), 0) AS income
         FROM transactions
         WHERE ${conditions.join(' AND ')}
         GROUP BY month
         ORDER BY month''',
      args,
    );
    return rows.map((r) {
      return (
        r['month'] as String,
        (r['expense'] as int?) ?? 0,
        (r['income'] as int?) ?? 0,
      );
    }).toList();
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  /// Insert a new transaction. Returns its generated id.
  Future<int> insert(Transaction transaction) async {
    final db = await LocalDatabase.database;
    return db.insert('transactions', transaction.toMap());
  }

  /// Update an existing transaction.
  Future<int> update(Transaction transaction) async {
    final db = await LocalDatabase.database;
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Delete a transaction by [id].
  Future<int> delete(int id) async {
    final db = await LocalDatabase.database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete every transaction belonging to [ledgerId].
  Future<int> deleteByLedger(int ledgerId) async {
    final db = await LocalDatabase.database;
    return db.delete('transactions',
        where: 'ledger_id = ?', whereArgs: [ledgerId]);
  }
}
