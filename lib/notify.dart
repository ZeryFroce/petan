import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database.dart';
import 'models.dart';

class NotifyService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    // Android 13+ 运行时通知权限
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await checkDueReminders();
  }

  static Future<void> notify(String title, String body) async {
    const detail = NotificationDetails(
      android: AndroidNotificationDetails(
        'pet_health_reminder',
        '宠物提醒',
        channelDescription: '疫苗、驱虫、体检等到期提醒',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: DateTime.now().microsecond,
      title: title,
      body: body,
      notificationDetails: detail,
    );
  }

  // 检查到期提醒并发送系统通知（App 启动时 / 切回前台时调用）
  static Future<void> checkDueReminders() async {
    final due = await DatabaseHelper.instance.getDueReminders();
    if (due.isEmpty) return;
    final pets = await DatabaseHelper.instance.getPets();
    final nameById = {for (final p in pets) p.id: p.name};
    if (due.length == 1) {
      final r = due.first;
      final name = nameById[r.petId] ?? '宠物';
      await notify('$name 的提醒', r.title);
    } else {
      final lines = due
          .map((r) => '· ${(nameById[r.petId] ?? '宠物')}：${r.title}')
          .join('\n');
      await notify('您有 ${due.length} 条待办提醒', lines);
    }
  }
}
