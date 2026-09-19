import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'database.dart';
import 'notify.dart';
import 'shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await NotifyService.init();
  final s = await DatabaseHelper.instance.getSettings();
  final lockOn = s?.lockEnabled == 1 && (s?.lockPin?.isNotEmpty ?? false);
  final bioOn = s?.bioEnabled == 1;
  // 启动时恢复上次选择的主题（默认暖橙）
  setAppTheme(s?.theme ?? 'light');
  runApp(AppRoot(lockOn: lockOn, bioOn: bioOn, pin: s?.lockPin));
}

class AppRoot extends StatefulWidget {
  final bool lockOn;
  final bool bioOn;
  final String? pin;

  const AppRoot({super.key, required this.lockOn, required this.bioOn, required this.pin});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.lockOn;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotifyService.checkDueReminders();
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appThemeId,
      builder: (context, _, __) => MaterialApp(
        title: '宠安',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _locked
            ? LockPage(pin: widget.pin!, bioOn: widget.bioOn, onUnlock: _unlock)
            : const MainShell(),
      ),
    );
  }
}

class LockPage extends StatefulWidget {
  final String pin;
  final bool bioOn;
  final VoidCallback onUnlock;

  const LockPage({
    super.key,
    required this.pin,
    required this.bioOn,
    required this.onUnlock,
  });

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final _c = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.bioOn) {
      // 等首帧渲染完成再触发系统认证框，避免 Activity 尚未就绪导致无反应
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBio());
    }
  }

  Future<void> _tryBio() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final can = await _localAuth.canCheckBiometrics;
      final bios = await _localAuth.getAvailableBiometrics();
      if (!supported || (!can && bios.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前设备未启用指纹/面容，请改用密码解锁')),
          );
        }
        return;
      }
      final did = await _localAuth.authenticate(
        localizedReason: '使用指纹/面容解锁宠安',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (did && mounted) widget.onUnlock();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生物识别失败：$e')),
        );
      }
    }
  }

  void _check() {
    if (_c.text == widget.pin) {
      widget.onUnlock();
    } else {
      setState(() => _err = '密码错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text('🐾', style: TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 24),
              Text('宠安', style: AppText.h1),
              const SizedBox(height: 6),
              Text('请输入密码解锁', style: AppText.sub),
              const SizedBox(height: 28),
              TextField(
                controller: _c,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  errorText: _err,
                  hintText: '4-6 位数字',
                  counterText: '',
                ),
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _check, child: Text('解锁')),
              ),
              if (widget.bioOn) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _tryBio,
                  icon: Icon(Icons.fingerprint, color: AppColors.primary),
                  label: Text(
                    '指纹 / 面容解锁',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
