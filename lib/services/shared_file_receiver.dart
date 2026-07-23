import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Listen for .xlsx files shared to the app (from WeChat, Files, etc.).
class SharedFileReceiver {
  SharedFileReceiver._();

  static const _channel = MethodChannel('cn.zhuhkblog.billbuddy/share');

  static final _fileController = StreamController<String>.broadcast();

  /// Notifies when a new file is shared (for auto-navigation).
  static final pendingFile = ValueNotifier<String?>(null);

  /// Stream of file paths shared to the app.
  static Stream<String> get fileStream => _fileController.stream;

  /// Set up the listener (call once at app startup).
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileShared') {
        final path = call.arguments as String?;
        if (path != null && File(path).existsSync()) {
          _fileController.add(path);
          pendingFile.value = path;
        }
      }
    });
    // Check for cold-start shared file after a short delay.
    Future.delayed(const Duration(milliseconds: 500), () async {
      final path = await _getInitialSharedFile();
      if (path != null && File(path).existsSync()) {
        _fileController.add(path);
        pendingFile.value = path;
      }
    });
  }

  static Future<String?> _getInitialSharedFile() async {
    try {
      return await _channel.invokeMethod<String>('getInitialFile');
    } catch (_) {
      return null;
    }
  }

  /// Clear the pending file after it has been handled.
  static void clearPending() {
    pendingFile.value = null;
  }
}
