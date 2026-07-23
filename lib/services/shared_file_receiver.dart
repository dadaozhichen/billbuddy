import 'dart:async';

import 'package:flutter/services.dart';

/// Listen for .xlsx files shared to the app (from WeChat, Files, etc.).
class SharedFileReceiver {
  SharedFileReceiver._();

  static const _channel = MethodChannel('cn.zhuhkblog.billbuddy/share');

  static final _fileController = StreamController<String>.broadcast();

  /// Stream of file paths shared to the app.
  static Stream<String> get fileStream => _fileController.stream;

  /// Set up the listener (call once at app startup).
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileShared') {
        final path = call.arguments as String?;
        if (path != null) {
          _fileController.add(path);
        }
      }
    });
  }

  /// Check if the app was opened with a shared file (for cold start).
  static Future<String?> getInitialSharedFile() async {
    try {
      final path = await _channel.invokeMethod<String>('getInitialFile');
      return path;
    } catch (_) {
      return null;
    }
  }
}
