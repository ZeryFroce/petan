import 'package:flutter/material.dart';

import 'home_page.dart';
import 'reminders_page.dart';
import 'health_page.dart';
import 'profile_page.dart';

/// 底部导航骨架。
/// 用 IndexedStack 承载四个一级页面，切换时保持各页状态，并通过 key 触发对应页刷新数据。
/// （此前实现中点按底部项只是 push 新页面、selectedIndex 从不更新，导航实际失效。）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _remindersKey = GlobalKey<RemindersPageState>();
  final _healthKey = GlobalKey<HealthPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();

  void _refreshAt(int i) {
    switch (i) {
      case 0:
        _homeKey.currentState?.refresh();
      case 1:
        _remindersKey.currentState?.refresh();
      case 2:
        _healthKey.currentState?.refresh();
      case 3:
        _profileKey.currentState?.refresh();
    }
  }

  void select(int i) {
    if (i == _index) {
      _refreshAt(i);
      return;
    }
    setState(() => _index = i);
    _refreshAt(i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(key: _homeKey, onViewReminders: () => select(1)),
          RemindersPage(key: _remindersKey),
          HealthPage(key: _healthKey),
          ProfilePage(key: _profileKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: select,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined),
            activeIcon: Icon(Icons.pets),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_outlined),
            activeIcon: Icon(Icons.notifications_none),
            label: '提醒',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '健康',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
