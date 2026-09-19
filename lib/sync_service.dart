import 'dart:convert';
import 'dart:typed_data';
import 'package:webdav_client/webdav_client.dart' as wd;
import 'database.dart';
import 'models.dart';

class SyncService {
  static Future<wd.Client> _client(AppSettings s) async {
    final url = (s.webdavUrl ?? '').trim();
    return wd.newClient(
      url,
      user: (s.webdavUser ?? '').trim(),
      password: (s.webdavPass ?? '').trim(),
    );
  }

  static String _remotePath(AppSettings s) {
    var dir = (s.webdavDir ?? '').trim();
    while (dir.endsWith('/')) dir = dir.substring(0, dir.length - 1);
    return dir.isEmpty ? '/pet_health_backup.json' : '$dir/pet_health_backup.json';
  }

  // 上传本地全部数据到 WebDAV（覆盖远端同名文件）
  static Future<int> push() async {
    final s = await DatabaseHelper.instance.getSettings();
    if (s == null || !s.webdavConfigured) {
      throw Exception('WebDAV 未配置');
    }
    final client = await _client(s);
    final dir = (s.webdavDir ?? '').trim();
    if (dir.isNotEmpty) {
      try {
        await client.mkdirAll(dir);
      } catch (_) {/* 目录可能已存在，忽略 */}
    }
    final payload = await DatabaseHelper.instance.exportPayload();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    await client.write(_remotePath(s), bytes);
    return (payload['pets'] as List).length +
        (payload['records'] as List).length +
        (payload['reminders'] as List).length;
  }

  // 从 WebDAV 拉取并合并数据（仅新增本地缺失项）
  static Future<int> pull() async {
    final s = await DatabaseHelper.instance.getSettings();
    if (s == null || !s.webdavConfigured) {
      throw Exception('WebDAV 未配置');
    }
    final client = await _client(s);
    List<int> bytes;
    try {
      bytes = await client.read(_remotePath(s));
    } catch (e) {
      // 远端文件不存在视为暂无共享数据
      return 0;
    }
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return DatabaseHelper.instance.mergeData(data);
  }

  // 双向同步：先拉后推，保证家庭成员共享目录数据一致
  static Future<String> sync() async {
    final s = await DatabaseHelper.instance.getSettings();
    if (s == null || !s.webdavConfigured) {
      return '未配置 WebDAV';
    }
    final merged = await pull();
    final pushed = await push();
    return '已合并新增 $merged 条，已上传 $pushed 条';
  }

  // 自动同步开关下的便捷调用（不抛异常，便于后台静默执行）
  static Future<void> syncIfAuto() async {
    try {
      final s = await DatabaseHelper.instance.getSettings();
      if (s != null && s.autoSync == 1 && s.webdavConfigured) {
        await sync();
      }
    } catch (_) {/* 静默失败，避免影响主流程 */}
  }
}
