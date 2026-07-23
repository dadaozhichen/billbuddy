import 'dart:io';

import 'package:flutter/services.dart';

/// Listen for .xlsx files shared to the app (from WeChat, Files, etc.).
class SharedFileReceiver {
  SharedFileReceiver._();

  static const _channel = MethodChannel('cn.zhuhkblog.billbuddy/share');

  /// Callback invoked when a file is shared — ShellPage sets this to navigate.
  static void Function(String path)? onFileReceived;

  /// Whether a file has already been handled this session.
  static bool _handled = false;

  /// Set up the listener (call once at app startup).
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileShared') {
        _handleFile(call.arguments as String?);
      }
    });
    // Poll for a file opened at launch (macOS cold start).
    // Retry a few times since the native side may not be ready yet.
    _pollPendingFile();
  }

  static Future<void> _pollPendingFile() async {
    // Wait a bit for the Flutter engine and native channel to be ready.
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_handled) return;
      try {
        final path = await _channel.invokeMethod<String>('popPendingFile');
        if (path != null && File(path).existsSync()) {
          _handled = true;
          onFileReceived?.call(path);
          return;
        }
        if (path == null) return;
      } catch (_) {
        // native channel not ready yet
      }
    }
  }

  static void _handleFile(String? path) {
    if (path == null || !File(path).existsSync()) return;
    _handled = true;
    onFileReceived?.call(path);
  }
}
