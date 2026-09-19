import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'database.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String _msg = '';

  Future<String> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/pet_health_backup.json';
  }

  Future<void> _export() async {
    final payload = await DatabaseHelper.instance.exportPayload();
    final file = File(await _backupFile());
    await file.writeAsString(jsonEncode(payload));
    setState(() => _msg = '已导出至：\n${file.path}\n将该文件复制到其他设备同一目录即可恢复。');
  }

  Future<void> _import() async {
    final file = File(await _backupFile());
    if (!file.existsSync()) {
      setState(() => _msg = '未找到备份文件：\n${file.path}\n请将 pet_health_backup.json 放入该目录后重试。');
      return;
    }
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await DatabaseHelper.instance.importData(data);
      setState(() => _msg = '导入成功：宠物 ${data['pets']?.length ?? 0} 条，记录 ${data['records']?.length ?? 0} 条，相册 ${data['album']?.length ?? 0} 条');
    } catch (e) {
      setState(() => _msg = '导入失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF5A623)),
                SizedBox(width: 10),
                Expanded(child: Text('数据保存在本机，支持导出为 JSON 文件自行保管。将备份文件放在应用私有目录后点“从备份恢复”即可还原。')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _export, icon: const Icon(Icons.upload), label: Text('导出备份文件'))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.download), label: Text('从备份恢复'))),
          const SizedBox(height: 24),
          if (_msg.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: SelectableText(_msg),
            ),
        ],
      ),
    );
  }
}
