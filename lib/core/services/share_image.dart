import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يلتقط أي [RepaintBoundary] معرّف بمفتاح [GlobalKey] كصورة PNG
/// ويستدعي ما يشاركها في أي تطبيق (واتساب، إيميل، ...).
class ShareImageService {
  static final ShareImageService instance = ShareImageService._();

  ShareImageService._();

  RenderRepaintBoundary? _boundaryOf(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is RenderRepaintBoundary) return renderObject;
    return null;
  }

  /// يلتقط [key] ويشارك الصورة. [fileName] اسم مؤقت للملف،
  /// [subject] يظهر في تطبيق المشاركة.
  Future<bool> share(
    GlobalKey key, {
    String fileName = 'share.png',
    String? subject,
    String? text,
  }) async {
    final boundary = _boundaryOf(key);
    if (boundary == null) return false;

    final pixelRatio = ui.PlatformDispatcher
        .instance.views.first.devicePixelRatio;
    final image = await boundary.toImage(
      pixelRatio: pixelRatio.clamp(1.0, 3.0),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return false;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: subject,
        text: text,
      ),
    );
    return true;
  }
}