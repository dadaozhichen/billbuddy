import '../../models/category.dart';
import '../datasources/local_database.dart';

/// Repository for reading and writing [Category] records.
///
/// All methods work against the shared [LocalDatabase] instance and
/// throw on database errors — callers are expected to handle or
/// propagate them as appropriate.
class CategoryRepository {
  CategoryRepository._();

  static final CategoryRepository _instance = CategoryRepository._();
  static CategoryRepository get instance => _instance;

  // ------------------------------------------------------------------
  // Queries
  // ------------------------------------------------------------------

  /// All categories, ordered by type (expense first) then id.
  Future<List<Category>> getAll() async {
    final db = await LocalDatabase.database;
    final rows = await db.query('categories', orderBy: 'type, id');
    return rows.map(Category.fromMap).toList();
  }

  /// Categories for a specific [TransactionType].
  Future<List<Category>> getByType(TransactionType type) async {
    final db = await LocalDatabase.database;
    final rows = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'id',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// A single category by [id], or `null` if it doesn't exist.
  Future<Category?> getById(int id) async {
    final db = await LocalDatabase.database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------

  /// Insert a new category. Returns its generated id.
  Future<int> insert(Category category) async {
    final db = await LocalDatabase.database;
    return db.insert('categories', category.toMap());
  }

  /// Update an existing category. Returns the number of rows affected.
  Future<int> update(Category category) async {
    final db = await LocalDatabase.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Delete a category by [id]. Returns the number of rows affected.
  Future<int> delete(int id) async {
    final db = await LocalDatabase.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
