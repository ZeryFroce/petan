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
  String _themeId = 'light';
  int _petCount = 0;
  int _recordCount = 0;
  int _reminderCount = 0;
  List<Pet> _archivedPets = [];

  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final s = await DatabaseHelper.instance.getSettings();
    final pets = await DatabaseHelper.instance.getPets();
    final archived = await DatabaseHelper.instance.getArchivedPets();
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
      _archivedPets = archived;
      _themeId = appThemeId.value;
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

  /// 切换并持久化主题
  Future<void> _selectTheme(String id) async {
    if (!setAppTheme(id)) return;
    setState(() => _themeId = id);
    final s = await DatabaseHelper.instance.getSettings();
    await DatabaseHelper.instance.saveSettings(
      AppSettings(
        theme: id,
        lockEnabled: s?.lockEnabled ?? 0,
        lockPin: s?.lockPin,
        bioEnabled: s?.bioEnabled ?? 0,
        webdavUrl: s?.webdavUrl,
        webdavUser: s?.webdavUser,
        webdavPass: s?.webdavPass,
        webdavDir: s?.webdavDir,
        autoSync: s?.autoSync ?? 0,
      ),
    );
  }

  Future<void> _restorePet(Pet p) async {
    final ok = await showConfirm(context,
        title: '恢复「${p.name}」？',
        content: '恢复后将重新出现在首页与健康等页面，数据完好保留。',
        confirmLabel: '恢复');
    if (!ok) return;
    await DatabaseHelper.instance.setPetArchived(p.id, 0);
    refresh();
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
            Text('我的', style: AppText.h1),
            const SizedBox(height: 2),
            Text('数据全部保存在本机，离线可用', style: AppText.faint),
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
            const SectionHeader(title: '主题外观'),
            const SizedBox(height: AppSpace.md),
            _themeCard(),
            const SizedBox(height: AppSpace.xl),
            if (_archivedPets.isNotEmpty) ...[
              const SectionHeader(title: '已归档宠物'),
              const SizedBox(height: AppSpace.md),
              _archivedCard(),
              const SizedBox(height: AppSpace.xl),
            ],
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
            Center(
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
                Text(
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

  Widget _themeCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择一款喜欢的配色', style: AppText.sub),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.md,
            children: kAppThemes.map((def) {
              final selected = def.id == _themeId;
              return GestureDetector(
                onTap: () => _selectTheme(def.id),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: def.tokens.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.text
                              : def.tokens.border,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: selected
                            ? const Icon(Icons.check,
                                size: 22, color: Colors.white)
                            : Text(def.emoji,
                                style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(def.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? AppColors.text
                              : AppColors.textSub,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _archivedCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        children: _archivedPets
            .map((p) => ListTile(
                  leading: Text(speciesEmoji(p.species),
                      style: const TextStyle(fontSize: 24)),
                  title: Text(p.name),
                  subtitle: const Text('已归档 · 数据保留中'),
                  trailing: TextButton(
                    onPressed: () => _restorePet(p),
                    child: const Text('恢复'),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _securityCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        children: [
          SwitchListTile(
            title: Text('启用密码锁'),
            subtitle: Text('每次启动需输入密码'),
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
              title: Text('指纹 / 面容解锁'),
              subtitle: Text('锁屏时可用生物识别快速解锁'),
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
              child: FilledButton(onPressed: _saveSecurity, child: Text('保存安全设置')),
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
            leading: Icon(Icons.backup_outlined, color: AppColors.primary),
            title: Text('备份与恢复'),
            subtitle: Text('导出 / 导入本地 JSON 档案'),
            trailing: Icon(Icons.chevron_right, color: AppColors.textFaint),
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
              Icon(Icons.cloud_sync_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text('WebDAV 同步', style: AppText.h3)),
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
            title: Text('自动同步'),
            subtitle: Text('数据变更后自动上传并合并共享目录'),
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
            child: Text(
              '家庭成员共享：在不同设备填写同一个 WebDAV 目录即可共享宠物档案。同步采用「新增合并」策略，不会覆盖本机已有数据。',
              style: TextStyle(fontSize: 12, color: AppColors.textSub, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
