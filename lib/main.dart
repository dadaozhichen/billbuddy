import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/datasources/local_database.dart';
import 'providers/database_provider.dart';
import 'services/shared_file_receiver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Listen for shared .xlsx files (Android: from WeChat, Files, etc.).
  SharedFileReceiver.init();

  // Warm up the database before the first frame.
  final db = await LocalDatabase.database;

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const BillBuddyApp(),
    ),
  );
}
