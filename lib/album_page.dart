import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'database.dart';
import 'models.dart';
import 'thumbnail_cache.dart';

class AlbumPage extends StatefulWidget {
  final Pet pet;
  const AlbumPage({super.key, required this.pet});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  List<AlbumEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseHelper.instance.getAlbumEntries(widget.pet.id);
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _addToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final existing = await DatabaseHelper.instance.getAlbumEntryByDate(widget.pet.id, today);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今天已经记录过相册啦，明天再来吧~')));
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumEditPage(petId: widget.pet.id, date: today)),
    );
    if (result == true) _load();
  }

  void _openEntry(AlbumEntry e) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumEditPage(entry: e)),
    );
    if (result == true) _load();
  }

  void _showMemoryWall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemoryWallPage(entries: _entries, pet: widget.pet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pet.name}的相册'),
        actions: [
          IconButton(icon: const Icon(Icons.auto_awesome), tooltip: '回忆墙', onPressed: _showMemoryWall),
        ],
      ),
      body: _entries.isEmpty
          ? _emptyView()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return _entryCard(e);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addToday,
        icon: const Icon(Icons.add_photo_alternate),
        label: Text('记录今天'),
      ),
    );
  }

  Widget _emptyView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📷', style: TextStyle(fontSize: 64, color: Colors.orange.shade200)),
            const SizedBox(height: 16),
            Text('还没有照片记录', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('每天最多记录 1 次，最多 9 张照片', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );

  Widget _entryCard(AlbumEntry e) {
    final photos = e.photos;
    return GestureDetector(
      onTap: () => _openEntry(e),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(e.date, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const Spacer(),
                  if (e.editCount >= 1)
                    Text('已修改', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
                  else
                    Text('可修改 1 次', style: TextStyle(color: Colors.green.shade600, fontSize: 12)),
                ],
              ),
              if (e.note != null && e.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(e.note!, style: const TextStyle(color: Colors.black87)),
              ],
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photos.length,
                itemBuilder: (_, idx) => Hero(
                  tag: '${e.id}_$idx',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ThumbImage(photos[idx]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumEditPage extends StatefulWidget {
  final String? petId;
  final String? date;
  final AlbumEntry? entry;
  const AlbumEditPage({super.key, this.petId, this.date, this.entry});

  @override
  State<AlbumEditPage> createState() => _AlbumEditPageState();
}

class _AlbumEditPageState extends State<AlbumEditPage> {
  late bool _isEdit;
  late String _date;
  final _note = TextEditingController();
  final List<String> _paths = [];
  bool _compress = false;
  bool _canEdit = true;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.entry != null;
    _date = widget.entry?.date ?? widget.date ?? DateTime.now().toIso8601String().substring(0, 10);
    if (_isEdit) {
      _note.text = widget.entry!.note ?? '';
      _paths.addAll(widget.entry!.photos);
      _compress = widget.entry!.compressMode == 1;
      _canEdit = widget.entry!.editCount < 1;
    }
  }

  Future<void> _pickImages() async {
    if (_paths.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多选择 9 张照片')));
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked == null || picked.isEmpty) return;
    final remain = 9 - _paths.length;
    final selected = picked.take(remain).toList();

    final appDir = await getApplicationDocumentsDirectory();
    final albumDir = Directory('${appDir.path}/albums/${widget.petId ?? widget.entry!.petId}');
    if (!albumDir.existsSync()) albumDir.createSync(recursive: true);

    for (final f in selected) {
      final saved = await _saveImage(File(f.path), albumDir, compress: _compress);
      if (saved != null) _paths.add(saved);
    }
    if (mounted) setState(() {});
  }

  Future<String?> _saveImage(File source, Directory dir, {required bool compress}) async {
    try {
      final ext = p.extension(source.path).toLowerCase();
      final name = '${genId()}$ext';
      final dest = File('${dir.path}/$name');
      if (compress) {
        final bytes = await source.readAsBytes();
        img.Image? image;
        if (ext == '.png') {
          image = img.decodePng(bytes);
        } else {
          image = img.decodeJpg(bytes);
        }
        if (image == null) {
          await source.copy(dest.path);
          return dest.path;
        }
        // 等比压缩到最长边 1200
        const maxSide = 1200;
        int w = image.width;
        int h = image.height;
        if (w > maxSide || h > maxSide) {
          if (w > h) {
            h = (h * maxSide / w).round();
            w = maxSide;
          } else {
            w = (w * maxSide / h).round();
            h = maxSide;
          }
          image = img.copyResize(image, width: w, height: h);
        }
        if (ext == '.png') {
          await dest.writeAsBytes(img.encodePng(image));
        } else {
          await dest.writeAsBytes(img.encodeJpg(image, quality: 85));
        }
      } else {
        await source.copy(dest.path);
      }
      return dest.path;
    } catch (e) {
      debugPrint('save image error: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (_paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一张照片')));
      return;
    }
    final petId = widget.petId ?? widget.entry!.petId;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isEdit) {
      final entry = AlbumEntry(
        id: widget.entry!.id,
        petId: petId,
        date: _date,
        note: _note.text.trim(),
        photosJson: encodeAttachments(_paths),
        compressMode: _compress ? 1 : 0,
        editCount: widget.entry!.editCount + 1,
        createdAt: widget.entry!.createdAt,
      );
      await DatabaseHelper.instance.updateAlbumEntry(entry);
    } else {
      final entry = AlbumEntry(
        id: genId(),
        petId: petId,
        date: _date,
        note: _note.text.trim(),
        photosJson: encodeAttachments(_paths),
        compressMode: _compress ? 1 : 0,
        editCount: 0,
        createdAt: now,
      );
      await DatabaseHelper.instance.insertAlbumEntry(entry);
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _viewImage(int idx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: PhotoView(
            imageProvider: FileImage(File(_paths[idx])),
            heroAttributes: PhotoViewHeroAttributes(tag: '${widget.entry?.id ?? _date}_$idx'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '编辑相册记录' : '记录 $_date';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_canEdit)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('该记录已修改过 1 次，当前仅可浏览', style: TextStyle(color: Colors.orange))),
                ],
              ),
            ),
          if (!_canEdit) const SizedBox(height: 12),
          SwitchListTile(
            title: Text('压缩图片'),
            subtitle: Text('节省空间，推荐开启'),
            value: _compress,
            onChanged: _canEdit ? (v) => setState(() => _compress = v) : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            enabled: _canEdit,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '今日备注',
              hintText: '今天有什么变化？',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Text('照片（最多 9 张）', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _paths.length + (_canEdit && _paths.length < 9 ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _paths.length) {
                return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200, width: 2, style: BorderStyle.solid),
                    ),
                    child: const Icon(Icons.add_photo_alternate, color: Colors.orange, size: 36),
                  ),
                );
              }
              return GestureDetector(
                onTap: () => _viewImage(i),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_paths[i]), fit: BoxFit.cover),
                    ),
                    if (_canEdit)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _paths.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_canEdit)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEdit ? '保存修改' : '完成记录'),
            ),
        ],
      ),
    );
  }
}

class MemoryWallPage extends StatelessWidget {
  final List<AlbumEntry> entries;
  final Pet pet;
  const MemoryWallPage({super.key, required this.entries, required this.pet});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // 按“N 个月前的今天”或“去年同期"分组
    final memories = <Map<String, dynamic>>[];
    for (final e in entries) {
      final d = DateTime.tryParse(e.date);
      if (d == null) continue;
      final diffDays = now.difference(d).inDays;
      if (diffDays <= 0) continue;
      String label;
      if (diffDays >= 365 && now.month == d.month && now.day == d.day) {
        label = '${diffDays ~/ 365} 年前的今天';
      } else if (diffDays % 30 == 0 || (diffDays > 28 && diffDays < 34)) {
        label = '约 ${diffDays ~/ 30} 个月前';
      } else if (diffDays == 7 || diffDays == 14 || diffDays == 21 || diffDays == 28) {
        label = '${diffDays ~/ 7} 周前';
      } else {
        continue;
      }
      memories.add({'entry': e, 'label': label, 'date': e.date});
    }
    // 去重：同一天只取一次
    final seen = <String>{};
    final unique = memories.where((m) => seen.add(m['date'] as String)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${pet.name}的回忆墙')),
      body: unique.isEmpty
          ? const Center(child: Text('还没有形成回忆，多记录一些照片吧~', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: unique.length,
              itemBuilder: (_, i) {
                final e = unique[i]['entry'] as AlbumEntry;
                final label = unique[i]['label'] as String;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(label, style: TextStyle(color: Colors.pink.shade800, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: e.photos.length,
                          itemBuilder: (_, idx) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ThumbImage(e.photos[idx]),
                          ),
                        ),
                        if (e.note != null && e.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(e.note!, style: const TextStyle(color: Colors.black87)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
