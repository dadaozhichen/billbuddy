import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../services/shared_file_receiver.dart';
import 'home_page.dart';
import 'import_preview_page.dart';
import 'statistics_page.dart';
import 'settings_page.dart';

/// Root scaffold with bottom navigation — persists tab state via IndexedStack.
class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    StatisticsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    SharedFileReceiver.pendingFile.addListener(_onPendingFile);
    final existing = SharedFileReceiver.pendingFile.value;
    if (existing != null) {
      _openImportPage(existing);
    }
  }

  @override
  void dispose() {
    SharedFileReceiver.pendingFile.removeListener(_onPendingFile);
    super.dispose();
  }

  void _onPendingFile() {
    final path = SharedFileReceiver.pendingFile.value;
    if (path != null) {
      _openImportPage(path);
    }
  }

  void _openImportPage(String path) {
    SharedFileReceiver.clearPending();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImportPreviewPage(initialFilePath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          // Notify pages to refresh when their tab is selected.
          if (i == 1) {
            // Statistics tab — bump counter so providers re-fetch.
            ref.read(tabSwitchProvider.notifier).state++;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
