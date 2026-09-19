import 'package:flutter/material.dart';

import 'database.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reminder_sheet.dart';

/// 提醒中心：按 已逾期 / 今天 / 即将到来 / 已完成 分组，支持勾选完成与删除。
/// 此前底部导航第 4 项标着"提醒"却打开设置页，真正的提醒视图并不存在。
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => RemindersPageState();
}

class RemindersPageState extends State<RemindersPage> {
  bool _loading = true;
  bool _showDone = false;
  List<Pet> _pets = [];
  List<Reminder> _all = [];
  final Map<String, String> _petNames = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final pets = await DatabaseHelper.instance.getPets();
    final rems = await DatabaseHelper.instance.getAllReminders();
    rems.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (!mounted) return;
    setState(() {
      _pets = pets;
      _all = rems;
      _petNames
        ..clear()
        ..addEntries(pets.map((p) => MapEntry(p.id, p.name)));
      _loading = false;
    });
  }

  List<Reminder> get _pending => _all.where((r) => r.done != 1).toList();

  List<Reminder> _byStatus(ReminderStatus s) =>
      _pending.where((r) => statusOf(r) == s).toList();

  List<Reminder> get _doneList =>
      _all.where((r) => r.done == 1).toList().reversed.toList();

  Future<void> _toggle(Reminder r, bool value) async {
    await DatabaseHelper.instance.updateReminder(
      Reminder(
        id: r.id,
        petId: r.petId,
        title: r.title,
        dueDate: r.dueDate,
        repeatRule: r.repeatRule,
        type: r.type,
        done: value ? 1 : 0,
        sourceRecordId: r.sourceRecordId,
        createdAt: r.createdAt,
      ),
    );
    refresh();
  }

  Future<void> _delete(Reminder r) async {
    final ok = await showConfirm(context, title: '删除提醒', content: '确定删除「${r.title}」？');
    if (!ok) return;
    await DatabaseHelper.instance.deleteReminder(r.id);
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _byStatus(ReminderStatus.overdue);
    final today = _byStatus(ReminderStatus.today);
    final soon = _byStatus(ReminderStatus.soon);
    final done = _doneList;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpace.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提醒', style: AppText.h1),
            const SizedBox(height: 2),
            Text(
              '${overdue.length + today.length} 项待处理 · 共 ${_all.length} 条',
              style: AppText.faint,
            ),
          ],
        ),
        toolbarHeight: 76,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refresh,
              child: _all.isEmpty
                  ? ListView(
                      children: [
                        AppCard(
                          child: EmptyState(
                            emoji: '⏰',
                            title: '还没有提醒',
                            subtitle: '为疫苗、驱虫、体检设置提醒，不再错过重要日程',
                            actionLabel: '添加提醒',
                            onAction: _add,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
                      children: [
                        if (overdue.isNotEmpty) _section('已逾期', overdue, AppColors.overdue),
                        if (today.isNotEmpty) _section('今天', today, AppColors.today),
                        if (soon.isNotEmpty) _section('即将到来', soon, AppColors.soon),
                        if (overdue.isEmpty && today.isEmpty && soon.isEmpty)
                          AppCard(
                            child: EmptyState(
                              emoji: '✅',
                              title: '待办已清空',
                              subtitle: '所有提醒都处理完啦',
                            ),
                          ),
                        const SizedBox(height: AppSpace.lg),
                        Row(
                          children: [
                            Expanded(child: Text('已完成', style: AppText.h3)),
                            TextButton(
                              onPressed: () => setState(() => _showDone = !_showDone),
                              child: Text(_showDone ? '隐藏' : '显示 (${done.length})'),
                            ),
                          ],
                        ),
                        if (_showDone) ...[
                          const SizedBox(height: AppSpace.md),
                          if (done.isEmpty)
                            AppCard(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: AppSpace.xl),
                                child: Center(child: Text('暂无已完成提醒', style: AppText.sub)),
                              ),
                            )
                          else
                            ...done.map((r) => _tile(r, AppColors.done)),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text('添加提醒'),
      ),
    );
  }

  Widget _section(String title, List<Reminder> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(title, style: AppText.h3),
              const SizedBox(width: AppSpace.sm),
              Text('${items.length}', style: AppText.faint),
            ],
          ),
        ),
        ...items.map((r) => _tile(r, color)),
      ],
    );
  }

  Widget _tile(Reminder r, Color color) {
    final isDone = r.done == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        child: Row(
          children: [
            Checkbox(
              value: isDone,
              activeColor: AppColors.done,
              shape: const CircleBorder(),
              onChanged: (v) => _toggle(r, v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: isDone
                        ? AppText.body.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textFaint,
                          )
                        : AppText.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_petNames[r.petId] ?? '', style: AppText.faint),
                      const SizedBox(width: AppSpace.sm),
                      Text(r.dueDate, style: AppText.faint),
                    ],
                  ),
                ],
              ),
            ),
            StatusChip(text: statusText(r), color: color),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.textFaint,
              onPressed: () => _delete(r),
            ),
          ],
        ),
      ),
    );
  }

  void _add() {
    showAddReminderSheet(context, pets: _pets, onSaved: refresh);
  }
}
