import 'package:flutter/material.dart';

import 'add_pet_page.dart';
import 'add_record_page.dart';
import 'database.dart';
import 'models.dart';
import 'pet_detail_page.dart';
import 'supplies_page.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/reminder_sheet.dart';

/// 首页：全局概览。
/// 待办提醒 → 宠物档案 → 最近动态，并提供统一快捷记录入口。
class HomePage extends StatefulWidget {
  final VoidCallback? onViewReminders;

  const HomePage({super.key, this.onViewReminders});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _loading = true;
  List<Pet> _pets = [];
  List<Reminder> _due = [];
  List<HealthRecord> _recent = [];
  List<Supply> _supplies = [];
  final Map<String, String?> _supplyExpiry = {}; // supplyId -> 最近一次入库保质期
  final Map<String, HealthScore> _scores = {};
  final Map<String, double?> _weights = {};
  final Map<String, String> _petNames = {};

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final pets = await DatabaseHelper.instance.getPets();
    final due = await DatabaseHelper.instance.getDueReminders();
    final all = await DatabaseHelper.instance.getAllRecords();
    final supplies = await DatabaseHelper.instance.getSupplies();
    final allLogs = await DatabaseHelper.instance.getAllSupplyLogs();

    // 每个用品最近一次入库的保质期（按流水日期取最新）
    final expiry = <String, String?>{};
    final latestLogDate = <String, String>{};
    for (final l in allLogs) {
      if (l.type != 'in' || l.expiryDate == null) continue;
      final cur = latestLogDate[l.supplyId];
      if (cur == null || l.date.compareTo(cur) >= 0) {
        latestLogDate[l.supplyId] = l.date;
        expiry[l.supplyId] = l.expiryDate;
      }
    }

    final Map<String, HealthScore> scores = {};
    final Map<String, double?> weights = {};
    for (final p in pets) {
      final recs = await DatabaseHelper.instance.getRecords(p.id);
      scores[p.id] = computeHealthScore(records: recs, days: 30);
      final w = await DatabaseHelper.instance.getRecords(p.id, type: 'weight');
      weights[p.id] = w.isNotEmpty ? w.first.weightKg : null;
    }

    if (!mounted) return;
    setState(() {
      _pets = pets;
      _due = due;
      _recent = all.take(5).toList();
      _supplies = supplies;
      _supplyExpiry
        ..clear()
        ..addAll(expiry);
      _scores
        ..clear()
        ..addAll(scores);
      _weights
        ..clear()
        ..addAll(weights);
      _petNames
        ..clear()
        ..addEntries(pets.map((p) => MapEntry(p.id, p.name)));
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  Color _healthColor(String status) {
    switch (status) {
      case '非常健康':
        return AppColors.done;
      case '健康':
        return const Color(0xFF009688);
      case '一般':
        return AppColors.today;
      case '不佳':
        return Colors.deepOrange;
      default:
        return AppColors.overdue;
    }
  }

  Future<void> _complete(Reminder r) async {
    await DatabaseHelper.instance.updateReminder(
      Reminder(
        id: r.id,
        petId: r.petId,
        title: r.title,
        dueDate: r.dueDate,
        repeatRule: r.repeatRule,
        type: r.type,
        done: 1,
        sourceRecordId: r.sourceRecordId,
        createdAt: r.createdAt,
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _due.where((r) => statusOf(r) == ReminderStatus.overdue).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpace.lg,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$_greeting 👋', style: AppText.h1),
            const SizedBox(height: 2),
            Text(
              overdueCount > 0
                  ? '有 $overdueCount 项待办已逾期，记得处理'
                  : _due.isNotEmpty
                      ? '今天有 ${_due.length} 项待办'
                      : '毛孩子一切都好',
              style: AppText.faint,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
                children: [
                  if (_due.isNotEmpty) ...[
                    _buildDueCard(overdueCount),
                    const SizedBox(height: AppSpace.xl),
                  ],
                  _buildPetsSection(),
                  const SizedBox(height: AppSpace.xl),
                  _buildSuppliesSection(),
                  const SizedBox(height: AppSpace.xl),
                  _buildRecentSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickActions,
        icon: const Icon(Icons.add),
        label: Text('快速记录'),
      ),
    );
  }

  Widget _buildDueCard(int overdueCount) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: overdueCount > 0 ? AppColors.overdue : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  overdueCount > 0 ? '待办提醒 · $overdueCount 项逾期' : '今日待办',
                  style: AppText.h3,
                ),
              ),
              TextButton(onPressed: widget.onViewReminders, child: Text('查看全部')),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ..._due.take(3).map(_buildDueRow),
        ],
      ),
    );
  }

  Widget _buildDueRow(Reminder r) {
    final status = statusOf(r);
    final color = statusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${_petNames[r.petId] ?? ''} · ${r.dueDate}', style: AppText.faint),
              ],
            ),
          ),
          StatusChip(text: statusText(r), color: color),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 20),
            color: AppColors.done,
            tooltip: '标记完成',
            onPressed: () => _complete(r),
          ),
        ],
      ),
    );
  }

  Widget _buildPetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '我的毛孩子',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '共 ${_pets.length} 只',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (_pets.isEmpty)
          AppCard(
            child: EmptyState(
              emoji: '🐾',
              title: '还没有宠物档案',
              subtitle: '添加第一只毛孩子，开始记录它的健康点滴',
              actionLabel: '添加宠物',
              onAction: _addPet,
            ),
          )
        else
          ..._pets.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: _petCard(p),
            ),
          ),
      ],
    );
  }

  Widget _petCard(Pet p) {
    final hs = _scores[p.id];
    final w = _weights[p.id];
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PetDetailPage(pet: p)),
      ).then((_) => refresh()),
      child: Row(
        children: [
          PetAvatar(pet: p, size: 62),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppText.h3),
                const SizedBox(height: 3),
                Text(
                  [
                    speciesLabel(p.species),
                    if (p.breed != null && p.breed!.isNotEmpty) p.breed!,
                    if (p.ageDisplay != null) p.ageDisplay!,
                  ].join(' · '),
                  style: AppText.faint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (hs != null)
                      StatusChip(text: '健康 ${hs.score}/10', color: _healthColor(hs.status)),
                    if (w != null)
                      StatusChip(text: '${w.toStringAsFixed(1)} kg', color: AppColors.soon),
                    if (p.humanAge != null)
                      StatusChip(text: '≈人类 ${p.humanAge} 岁', color: const Color(0xFFE93D82)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textFaint),
        ],
      ),
    );
  }

  Widget _buildSuppliesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '用品柜',
          actionLabel: _supplies.isEmpty ? null : '查看全部',
          onAction: _openSupplies,
        ),
        const SizedBox(height: AppSpace.md),
        if (_supplies.isEmpty)
          AppCard(
            onTap: _openSupplies,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Center(child: Text('📦', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('把猫砂、零食、药品记进来', style: AppText.h3),
                      SizedBox(height: 2),
                      Text('入库、消耗、保质期一目了然', style: AppText.faint),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textFaint),
              ],
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _supplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (_, i) => _supplyMiniCard(_supplies[i]),
            ),
          ),
      ],
    );
  }

  Widget _supplyMiniCard(Supply s) {
    // 保质期提示（与用品柜同口径：30 天内临期 / 已过期标红）
    int? dte;
    Color? warn;
    final exp = _latestExpiry(s);
    if (exp != null) {
      final d = DateTime.tryParse(exp);
      if (d != null) {
        final now = DateTime.now();
        dte = DateTime(d.year, d.month, d.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (dte < 0) {
          warn = AppColors.overdue;
        } else if (dte <= 30) {
          warn = AppColors.today;
        }
      }
    }
    final lowStock = s.quantity > 0 && s.quantity <= 1;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: _openSupplies,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(supplyCategoryEmoji(s.category),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.name,
                      style: AppText.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  s.quantity == s.quantity.roundToDouble()
                      ? s.quantity.toStringAsFixed(0)
                      : s.quantity.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: lowStock ? AppColors.today : AppColors.text,
                  ),
                ),
                const SizedBox(width: 2),
                Text(s.unit, style: AppText.faint),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              warn != null
                  ? (dte! < 0 ? '已过期' : '临期 ${dte}天')
                  : lowStock
                      ? '库存告急'
                      : supplyCategoryLabel(s.category),
              style: TextStyle(
                fontSize: 11,
                color: warn ?? (lowStock ? AppColors.today : AppColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _latestExpiry(Supply s) {
    // 首页只加载了用品列表，未带流水；此处直接查询最新入库保质期
    // （数量少，开销可忽略；详细流水在用品柜页内查看）
    return _supplyExpiry[s.id];
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '最近动态'),
        const SizedBox(height: AppSpace.md),
        if (_recent.isEmpty)
          AppCard(
            child: EmptyState(
              emoji: '📖',
              title: '还没有记录',
              subtitle: '记录疫苗、体重、就诊等信息，形成完整的健康时间线',
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Column(
              children: _recent
                  .map(
                    (r) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(recordTypeEmoji(r.type), style: const TextStyle(fontSize: 18)),
                      ),
                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${_petNames[r.petId] ?? ''} · ${r.recordDate}',
                        style: AppText.faint,
                      ),
                      trailing: (r.cost != null && r.cost! > 0)
                          ? Text('¥${r.cost!.toStringAsFixed(0)}', style: AppText.sub)
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  void _addPet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPetPage(onSaved: refresh)),
    ).then((_) => refresh());
  }

  void _openSupplies() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SuppliesPage(pets: _pets)),
    ).then((_) => refresh());
  }

  void _showQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.pets, color: AppColors.primary),
              title: Text('添加宠物'),
              onTap: () {
                Navigator.pop(ctx);
                _addPet();
              },
            ),
            ListTile(
              leading: Icon(Icons.note_add_outlined, color: AppColors.primary),
              title: Text('记一笔健康'),
              onTap: () {
                Navigator.pop(ctx);
                _withPet((p) => AddRecordPage(petId: p.id, onSaved: refresh));
              },
            ),
            ListTile(
              leading: Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
              title: Text('记体重'),
              onTap: () {
                Navigator.pop(ctx);
                _withPet((p) => AddRecordPage(petId: p.id, onSaved: refresh, initialType: 'weight'));
              },
            ),
            ListTile(
              leading: Icon(Icons.alarm_add, color: AppColors.primary),
              title: Text('添加提醒'),
              onTap: () {
                Navigator.pop(ctx);
                showAddReminderSheet(context, pets: _pets, onSaved: refresh);
              },
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: AppColors.primary),
              title: Text('用品柜 · 入库 / 消耗'),
              onTap: () {
                Navigator.pop(ctx);
                _openSupplies();
              },
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }

  /// 单只宠物直接跳转，多只时先选择。
  void _withPet(Widget Function(Pet) builder) {
    if (_pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加宠物')),
      );
      return;
    }
    if (_pets.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => builder(_pets.first)),
      ).then((_) => refresh());
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择宠物', style: AppText.h3),
              ),
            ),
            ..._pets.map(
              (p) => ListTile(
                leading: PetAvatar(pet: p, size: 40),
                title: Text(p.name),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => builder(p)),
                  ).then((_) => refresh());
                },
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}
