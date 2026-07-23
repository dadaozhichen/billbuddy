import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Injected in [main] after the database is opened.
///
/// Every repository provider depends on this, ensuring a single
/// connection is shared across the app.
final databaseProvider = Provider<Database>((ref) {
  throw StateError('Database not initialized — call main() first.');
});
