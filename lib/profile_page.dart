import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'backup_page.dart';
import 'database.dart';
import 'models.dart';
import 'sync_service.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// 我的：安全（密码锁/生物识别）、数据（备份、WebDAV 同步）、关于。
/// 此前设置入口被放到了标着「提醒」的底部导航项下，且备份只藏在首页右上角图标里，发现性很差。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final _pin = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _dir = TextEditingController();

  bool _loading = true;
  bool _lockEnabled = false;
  bool _bioEnabled = false;
  bool _bioAvailable = false;
  bool _autoSync = false;
  bool _syncing = false;
  String _hint = '';
  int _petCount = 0;
  int _recordCount = 0;
  int _reminderCount = 0;

  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final s = await DatabaseHelper.instance.getSettings();
    final pets = await DatabaseHelper.instance.getPets();
    final recs = await DatabaseHelper.instance.getAllRecords();
    final rems = await DatabaseHelper.instance.getAllReminders();

    bool available = false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final can = await _localAuth.canCheckBiometrics;
      final bios = await _localAuth.getAvailableBiometrics();
      available = supported && (can || bios.isNotEmpty);
    } catch (_) {
      available = false;
    }

    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _petCount = pets.length;
      _recordCount = recs.length;
      _reminderCount = rems.length;
      if (s != null) {
        _lockEnabled = s.lockEnabled == 1;
        _bioEnabled = s.bioEnabled == 1;
        _autoSync = s.autoSync == 1;
        _url.text = s.webdavUrl ?? '';
        _user.text = s.webdavUser ?? '';
        _pass.text = s.webdavPass ?? '';
        _dir.text = s.webdavDir ?? '';
      }
      _loading = false;
    });
  }

  Future<void> _saveSecurity() async {
    final pin = _pin.text.trim();
    if (_lockEnabled && pin.length < 4) {
      setState(() => _hint = '请设置至少 4 位数字密码');
      return;
    }
    if (_bioEnabled && !_lockEnabled) {
      setState(() => _hint = '开启生物识别前需先启用密码锁');
      return;
    }
    final s = await DatabaseHelper.instance.getSettings();
    await DatabaseHelper.instance.saveSettings(
      AppSettings(
        theme: s?.theme ?? 'system',
        lockEnabled: _lockEnabled ? 1 : 0,
        lockPin: _lockEnabled ? pin : s?.lockPin,
        bioEnabled: _bioEnabled ? 1 : 0,
        webdavUrl: _url.text.trim(),
        webdavUser: _user.text.trim(),
        webdavPass: _pass.text.trim(),
        webdavDir: _dir.text.trim(),
        autoSync: _autoSync ? 1 : 0,
      ),
    );
    setState(() => _hint = '安全设置已保存');
    _pin.clear();
  }

  Future<void> _saveWebdav() async {
    final s = await DatabaseHelper.instance.getSettings();
    await DatabaseHelper.instance.saveSettings(
      AppSettings(
        theme: s?.theme ?? 'system',
        lockEnabled: s?.lockEnabled ?? 0,
        lockPin: s?.lockPin,
        bioEnabled: s?.bioEnabled ?? 0,
        webdavUrl: _url.text.trim(),
        webdavUser: _user.text.trim(),
        webdavPass: _pass.text.trim(),
        webdavDir: _dir.text.trim(),
        autoSync: _autoSync ? 1 : 0,
      ),
    );
    setState(() => _hint = '同步配置已保存');
  }

  Future<void> _doSync() async {
    if (_syncing) return;
    await _saveWebdav();
    final s = await DatabaseHelper.instance.getSettings();
    if (s == null || !s.webdavConfigured) {
      setState(() => _hint = '请先填写完整的 WebDAV 地址、账号与密码');
      return;
    }
    setState(() {
      _syncing = true;
      _hint = '正在同步…';
    });
    try {
      final msg = await SyncService.sync();
      setState(() => _hint = msg);
    } catch (e) {
      setState(() => _hint = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpace.lg,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('我的', style: AppText.h1),
            const SizedBox(height: 2),
            const Text('数据全部保存在本机，离线可用', style: AppText.faint),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
          children: [
            _heroCard(),
            const SizedBox(height: AppSpace.xl),
            const SectionHeader(title: '安全与隐私'),
            const SizedBox(height: AppSpace.md),
            _securityCard(),
            const SizedBox(height: AppSpace.xl),
            const SectionHeader(title: '数据管理'),
            const SizedBox(height: AppSpace.md),
            _dataCard(),
            const SizedBox(height: AppSpace.xl),
            _webdavCard(),
            if (_hint.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Center(child: Text(_hint, style: AppText.sub, textAlign: TextAlign.center)),
            ],
            const SizedBox(height: AppSpace.xl),
            const Center(
              child: Text('宠安 · 本地优先的猫狗健康档案工具', style: AppText.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD79A), Color(0xFFF5A623)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🐾', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '宠安',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '数据存于本机，无账号、无云端',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('启用密码锁'),
            subtitle: const Text('每次启动需输入密码'),
            value: _lockEnabled,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() {
              _lockEnabled = v;
              if (!v) _bioEnabled = false;
            }),
          ),
          if (_lockEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md),
              child: TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '设置密码 (4-6 位数字)',
                  counterText: '',
                ),
              ),
            ),
          if (_bioAvailable)
            SwitchListTile(
              title: const Text('指纹 / 面容解锁'),
              subtitle: const Text('锁屏时可用生物识别快速解锁'),
              value: _bioEnabled,
              activeColor: AppColors.primary,
              onChanged: _lockEnabled ? (v) => setState(() => _bioEnabled = v) : null,
            )
          else
            const ListTile(
              leading: Icon(Icons.fingerprint),
              title: Text('指纹 / 面容解锁'),
              subtitle: Text('当前设备未录入生物特征'),
              enabled: false,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _saveSecurity, child: const Text('保存安全设置')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined, color: AppColors.primary),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出 / 导入本地 JSON 档案'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textFaint),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupPage()),
            ).then((_) => refresh()),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(label: '宠物', value: '$_petCount', unit: '只'),
                ),
                Expanded(
                  child: StatTile(label: '健康记录', value: '$_recordCount', unit: '条'),
                ),
                Expanded(
                  child: StatTile(label: '提醒', value: '$_reminderCount', unit: '条'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _webdavCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpace.sm),
              const Expanded(child: Text('WebDAV 同步', style: AppText.h3)),
              StatusChip(
                text: _autoSync ? '自动同步已开' : '未启用',
                color: _autoSync ? AppColors.done : AppColors.textFaint,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _url, decoration: const InputDecoration(labelText: '服务器地址', hintText: 'https://dav.example.com/dav/')),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _user, decoration: const InputDecoration(labelText: '账号')),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: '密码')),
          const SizedBox(height: AppSpace.md),
          TextField(controller: _dir, decoration: const InputDecoration(labelText: '远程目录 (可选)', hintText: '留空则存到根目录')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动同步'),
            subtitle: const Text('数据变更后自动上传并合并共享目录'),
            value: _autoSync,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _autoSync = v),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _syncing ? null : _doSync,
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(_syncing ? '同步中…' : '保存并立即同步'),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Text(
              '家庭成员共享：在不同设备填写同一个 WebDAV 目录即可共享宠物档案。同步采用「新增合并」策略，不会覆盖本机已有数据。',
              style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
