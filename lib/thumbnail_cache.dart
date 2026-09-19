import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 相册缩略图缓存：网格展示用低分辨率缩略图，点进大图仍看原图。
///
/// 缓存策略：
/// - 磁盘：缩略图写入原图同目录的 `.thumbs/` 下（`<名称>_t.jpg`），跨会话复用
/// - 内存：`_memCache` 保存 路径→缩略图路径 映射，命中即零开销
/// - 生成：串行队列逐张处理，避免几十张图同时解码造成内存尖峰
/// - 兜底：生成失败返回 null，调用方退回原图（配合 cacheWidth 降采样，依然不卡）

const int kThumbMaxSide = 480;
const int kGridDecodeWidth = 400; // 网格直接解码原图时的降采样宽度

final Map<String, String> _memCache = {};

// —— 简单串行队列：同一时刻只生成一张缩略图 ——
final List<_ThumbJob> _pending = [];
bool _draining = false;

class _ThumbJob {
  final String photoPath;
  final Completer<String?> completer = Completer<String?>();
  _ThumbJob(this.photoPath);
}

Future<String?> getThumbnail(String photoPath) {
  final cached = _memCache[photoPath];
  if (cached != null) return Future.value(cached);

  final job = _ThumbJob(photoPath);
  _pending.add(job);
  _drain();
  return job.completer.future;
}

Future<void> _drain() async {
  if (_draining) return;
  _draining = true;
  while (_pending.isNotEmpty) {
    final job = _pending.removeAt(0);
    try {
      final thumb = await _generate(job.photoPath);
      if (thumb != null) _memCache[job.photoPath] = thumb;
      job.completer.complete(thumb);
    } catch (_) {
      job.completer.complete(null);
    }
  }
  _draining = false;
}

Future<String?> _generate(String photoPath) async {
  final src = io.File(photoPath);
  if (!src.existsSync()) return null;

  final thumbDir =
      io.Directory('${src.parent.path}${io.Platform.pathSeparator}.thumbs');
  if (!thumbDir.existsSync()) thumbDir.createSync(recursive: true);
  final thumbPath =
      '${thumbDir.path}${io.Platform.pathSeparator}'
      '${p.basenameWithoutExtension(photoPath)}_t.jpg';
  final thumbFile = io.File(thumbPath);
  if (thumbFile.existsSync()) return thumbPath; // 已有磁盘缓存

  // 原生解码 + 按宽度降采样（只给 targetWidth 时保持宽高比）
  final bytes = await src.readAsBytes();
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: kThumbMaxSide,
  );
  final frame = await codec.getNextFrame();
  final data =
      await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  if (data == null) return null;

  await thumbFile.writeAsBytes(data.buffer.asUint8List());
  return thumbPath;
}

/// 网格缩略图组件：立即以降采样方式显示（已消除卡顿主因），
/// 磁盘缩略图生成完成后无感切换（gaplessPlayback 防闪烁）。
class ThumbImage extends StatefulWidget {
  final String path;
  final BoxFit fit;

  const ThumbImage(this.path, {super.key, this.fit = BoxFit.cover});

  @override
  State<ThumbImage> createState() => _ThumbImageState();
}

class _ThumbImageState extends State<ThumbImage> {
  String? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final thumb = await getThumbnail(widget.path);
    if (mounted && thumb != null) setState(() => _thumb = thumb);
  }

  @override
  Widget build(BuildContext context) {
    return Image.file(
      io.File(_thumb ?? widget.path),
      fit: widget.fit,
      cacheWidth: kGridDecodeWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low, // 网格缩放用低画质采样，更快
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF2EADD),
        child: const Icon(Icons.broken_image, color: Color(0xFFC1B5A5)),
      ),
    );
  }
}
