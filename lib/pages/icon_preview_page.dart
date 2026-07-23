import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_icon.dart';

/// Preview and export the BillBuddy app icon.
class IconPreviewPage extends StatefulWidget {
  const IconPreviewPage({super.key});

  @override
  State<IconPreviewPage> createState() => _IconPreviewPageState();
}

class _IconPreviewPageState extends State<IconPreviewPage> {
  final _boundaryKey = GlobalKey();

  Future<void> _exportIcon() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/billbuddy_icon.png';
      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles([XFile(path)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图标已保存: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('应用图标')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('BillBuddy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // ── Icon preview ───────────────────────────────
            RepaintBoundary(
              key: _boundaryKey,
              child: const BillBuddyIcon(size: 256),
            ),
            const SizedBox(height: 24),

            Text('导出为 1024×1024 PNG',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),

            // ── Export button ──────────────────────────────
            FilledButton.icon(
              onPressed: _exportIcon,
              icon: const Icon(Icons.file_download),
              label: const Text('导出图标'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '导出后即可在 Xcode / Android Studio 中\n设置为应用图标',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
