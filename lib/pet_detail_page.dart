import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';

import 'database.dart';
import 'models.dart';
import 'theme.dart';
import 'add_record_page.dart';
import 'add_pet_page.dart';
import 'album_page.dart';
import 'widgets/common.dart';
import 'widgets/reminder_sheet.dart';
import 'widgets/date_picker_sheet.dart';

/// 宠物详情页：头部概览 + 档案 / 记录 / 体重 / 相册 / 消费 五个 Tab。
/// 相册与装备均内联展示，避免此前的多级跳转。
class PetDetailPage extends StatefulWidget {
  final Pet pet;
  const PetDetailPage({super.key, required this.pet});

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Pet _pet;
  List<HealthRecord> _records = [];
  List<Reminder> _reminders = [];
  List<AlbumEntry> _album = [];
  List<Equipment> _equipments = [];
  String _typeFilter = 'all';
  String _range = 'month'; // 消费图表：month | year

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _tab = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await DatabaseHelper.instance.getRecords(_pet.id);
    final reminders = await DatabaseHelper.instance.getReminders(_pet.id);
    final album = await DatabaseHelper.instance.getAlbumEntries(_pet.id);
    final eqs = await DatabaseHelper.instance.getEquipments(_pet.id);
    if (!mounted) return;
    setState(() {
      _records = records;
      _reminders = reminders;
      _album = album;
      _equipments = eqs;
    });
  }

  // ---------------- 数据派生 ----------------

  List<HealthRecord> get _weightRecords {
    final ws = _records.where((r) => r.weightKg != null).toList()
      ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
    return ws;
  }

  double get _recordsCost => _records.fold(0, (s, r) => s + (r.cost ?? 0));

  double get _equipCost => _equipments.fold(0, (s, e) => s + e.price);

  double get _worth => _recordsCost + _equipCost;

  HealthScore get _score =>
      computeHealthScore(records: _records, days: 30);

  Color _statusColor(String status) {
    switch (status) {
      case '非常健康':
      case '健康':
        return AppColors.done;
      case '一般':
        return AppColors.today;
      case '不佳':
        return AppColors.overdue.withValues(alpha: 0.8);
      default:
        return AppColors.overdue;
    }
  }

  // ---------------- 头部 ----------------

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPetPage(pet: _pet, onSaved: () {}),
      ),
    );
    final fresh = await DatabaseHelper.instance.getPet(_pet.id);
    if (fresh != null && mounted) setState(() => _pet = fresh);
  }

  Future<void> _addRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecordPage(petId: _pet.id, onSaved: _load),
      ),
    );
    _load();
  }

  Future<void> _addWeight() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecordPage(
          petId: _pet.id,
          onSaved: _load,
          initialType: 'weight',
        ),
      ),
    );
    _load();
  }

  Future<void> _addReminder() async {
    await showAddReminderSheet(context, pets: [_pet], pet: _pet, onSaved: _load);
  }

  Future<void> _addPhoto() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final existing =
        await DatabaseHelper.instance.getAlbumEntryByDate(_pet.id, today);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天已经记录过相册啦，明天再来吧~')),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumEditPage(petId: _pet.id, date: today),
      ),
    );
    if (result == true) _load();
  }

  void _openMemoryWall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemoryWallPage(entries: _album, pet: _pet),
      ),
    );
  }

  Widget _header() {
    final hs = _score;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PetAvatar(pet: _pet, size: 64),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(_pet.name,
                              style: AppText.h1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppColors.textSub,
                          onPressed: _edit,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        speciesLabel(_pet.species),
                        if (_pet.breed != null && _pet.breed!.isNotEmpty)
                          _pet.breed,
                        if (_pet.ageDisplay != null) _pet.ageDisplay,
                      ].join(' · '),
                      style: AppText.sub,
                    ),
                  ],
                ),
              ),
              StatusChip(
                text: '${hs.score}分 ${hs.status}',
                color: _statusColor(hs.status),
                icon: Icons.favorite,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              StatTile(
                label: '年龄',
                value: _pet.ageDisplay ?? '--',
              ),
              StatTile(
                label: '体重',
                value: _latestWeight == null
                    ? '--'
                    : _latestWeight!.toStringAsFixed(1),
                unit: 'kg',
              ),
              StatTile(
                label: '身价',
                value: _worth.toStringAsFixed(0),
                unit: '¥',
                color: AppColors.primaryDark,
              ),
              StatTile(label: '记录', value: '${_records.length}', unit: '条'),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              _quickAction('📝', '记一笔', _addRecord),
              _quickAction('⚖️', '记体重', _addWeight),
              _quickAction('⏰', '加提醒', _addReminder),
              _quickAction('📷', '加照片', _addPhoto),
            ],
          ),
        ],
      ),
    );
  }

  double? get _latestWeight {
    final ws = _weightRecords;
    return ws.isEmpty ? null : ws.last.weightKg;
  }

  Widget _quickAction(String emoji, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(label, style: AppText.faint),
          ],
        ),
      ),
    );
  }

  // ---------------- Tab 1 档案 ----------------

  Widget _profileTab() {
    final hs = _score;
    final upcoming = _reminders
        .where((r) => r.done == 0)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('基本档案', style: AppText.h3),
              const SizedBox(height: AppSpace.xs),
              InfoRow(label: '物种', value: speciesLabel(_pet.species)),
              InfoRow(
                  label: '品种',
                  value:
                      (_pet.breed == null || _pet.breed!.isEmpty) ? '未填写' : _pet.breed!),
              InfoRow(label: '生日', value: _pet.birthday ?? '未填写'),
              InfoRow(label: '年龄', value: _pet.ageDisplay ?? '未填写'),
              InfoRow(
                  label: '人类年龄',
                  value: _pet.humanAge == null ? '--' : '约 ${_pet.humanAge} 岁'),
              InfoRow(label: '性别', value: _genderLabel(_pet.gender)),
              InfoRow(label: '绝育', value: _neuterLabel(_pet.neuter)),
              InfoRow(label: '备注', value: (_pet.note == null || _pet.note!.isEmpty) ? '无' : _pet.note!),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('健康评分', style: AppText.h3)),
                  StatusChip(
                    text: hs.status,
                    color: _statusColor(hs.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${hs.score}',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: _statusColor(hs.status))),
                  Text(' / 10', style: AppText.sub),
                  const Spacer(),
                  Text('基础分 10 · 规则化加减分', style: AppText.faint),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: hs.score / 10,
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  color: _statusColor(hs.status),
                ),
              ),
              if (hs.reasons.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: hs.reasons
                      .map((r) => StatusChip(text: r, color: AppColors.textSub))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('待办提醒', style: AppText.h3),
              const SizedBox(height: AppSpace.xs),
              if (upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Text('暂无待办提醒', style: AppText.sub),
                )
              else
                ...upcoming.take(5).map((r) => _reminderRow(r)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reminderRow(Reminder r) {
    final st = statusOf(r);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Checkbox(
            value: false,
            onChanged: (_) async {
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
              _load();
            },
          ),
          Expanded(
            child: Text(r.title, style: AppText.body, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpace.sm),
          StatusChip(text: statusText(r), color: statusColor(st)),
        ],
      ),
    );
  }

  String _genderLabel(String? g) {
    switch (g) {
      case 'male':
        return '♂ 公';
      case 'female':
        return '♀ 母';
      default:
        return '未知';
    }
  }

  String _neuterLabel(String? n) {
    switch (n) {
      case 'neutered':
        return '已绝育';
      case 'intact':
        return '未绝育';
      default:
        return '未知';
    }
  }

  // ---------------- Tab 2 记录 ----------------

  Widget _recordsTab() {
    final types = _records.map((r) => r.type).toSet().toList();
    final filtered = _typeFilter == 'all'
        ? _records
        : _records.where((r) => r.type == _typeFilter).toList()
      ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

    final list = _typeFilter == 'all'
        ? (_records.toList()..sort((a, b) => b.recordDate.compareTo(a.recordDate)))
        : filtered;

    if (_records.isEmpty) {
      return EmptyState(
        emoji: '📋',
        title: '还没有健康记录',
        subtitle: '疫苗、驱虫、体检、体重都可以记在这里',
        actionLabel: '记一笔',
        onAction: _addRecord,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.sm),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: ChoiceChip(
                  label: const Text('全部'),
                  selected: _typeFilter == 'all',
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _typeFilter == 'all' ? Colors.white : AppColors.textSub,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _typeFilter = 'all'),
                ),
              ),
              ...types.map((t) => Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: ChoiceChip(
                      label: Text(recordTypeLabel(t)),
                      selected: _typeFilter == t,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color:
                            _typeFilter == t ? Colors.white : AppColors.textSub,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _typeFilter = t),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('该类型暂无记录', style: AppText.sub))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _recordCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _recordCard(HealthRecord r) {
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.lg),
        margin: const EdgeInsets.only(bottom: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.overdue,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => showConfirm(context,
          title: '删除这条记录？', content: r.title, confirmLabel: '删除'),
      onDismissed: (_) async {
        await DatabaseHelper.instance.deleteRecord(r.id);
        _load();
      },
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddRecordPage(petId: _pet.id, onSaved: _load, initialType: r.type),
            ),
          );
          _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(recordTypeEmoji(r.type),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(r.title,
                      style: AppText.h3, overflow: TextOverflow.ellipsis),
                ),
                Text(r.recordDate, style: AppText.faint),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                StatusChip(
                    text: recordTypeLabel(r.type), color: AppColors.primaryDark),
                if (r.cost != null && r.cost! > 0) ...[
                  const SizedBox(width: AppSpace.sm),
                  Text('¥${r.cost!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
                if (r.weightKg != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  Text('${r.weightKg!.toStringAsFixed(1)} kg', style: AppText.sub),
                ],
              ],
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(r.notes!, style: AppText.sub, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- Tab 3 体重 ----------------

  Widget _weightTab() {
    final ws = _weightRecords;
    if (ws.length < 2) {
      return EmptyState(
        emoji: '⚖️',
        title: '体重数据还不足',
        subtitle: ws.isEmpty ? '记录两次体重后即可看到趋势曲线' : '再记录一次体重就能生成趋势曲线',
        actionLabel: '记体重',
        onAction: _addWeight,
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < ws.length; i++) {
      spots.add(FlSpot(i.toDouble(), ws[i].weightKg!));
    }
    final weights = ws.map((r) => r.weightKg!).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final avgW = weights.fold(0.0, (s, w) => s + w) / weights.length;
    final delta = weights.last - weights.first;
    final padding = ((maxW - minW) * 0.2).clamp(0.5, 3.0);

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Row(
          children: [
            StatTile(label: '最低', value: minW.toStringAsFixed(1), unit: 'kg'),
            StatTile(label: '平均', value: avgW.toStringAsFixed(1), unit: 'kg'),
            StatTile(label: '最高', value: maxW.toStringAsFixed(1), unit: 'kg'),
            StatTile(
              label: '累计变化',
              value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
              unit: 'kg',
              color: delta >= 0 ? AppColors.overdue : AppColors.done,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.lg, AppSpace.md, AppSpace.sm),
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: (minW - padding).floorToDouble(),
                  maxY: (maxW + padding).ceilToDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => const FlLine(
                        color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (v, meta) => Text(
                          v.toStringAsFixed(1),
                          style: AppText.faint,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (ws.length / 5).ceilToDouble().clamp(1, 99),
                        getTitlesWidget: (v, meta) {
                          final idx = v.round();
                          if (idx < 0 || idx >= ws.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            ws[idx].recordDate.substring(5),
                            style: AppText.faint,
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: AppColors.primary,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('体重明细', style: AppText.h3),
              ...ws.reversed.take(10).map((r) {
                final idx = ws.indexOf(r);
                final prev = idx > 0 ? ws[idx - 1].weightKg : null;
                final d = prev == null ? null : r.weightKg! - prev;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.recordDate, style: AppText.body),
                      ),
                      if (d != null && d.abs() > 0.01)
                        Text(
                          '${d > 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 12,
                            color: d > 0 ? AppColors.overdue : AppColors.done,
                          ),
                        ),
                      const SizedBox(width: AppSpace.md),
                      Text('${r.weightKg!.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Tab 4 相册 ----------------

  Widget _albumTab() {
    if (_album.isEmpty) {
      return EmptyState(
        emoji: '📷',
        title: '还没有照片记录',
        subtitle: '每天最多记录 1 次，每次最多 9 张照片',
        actionLabel: '记录今天',
        onAction: _addPhoto,
      );
    }

    // 展平成时间线网格：按日期分组，直接展示在一级页面
    final cells = <_AlbumCell>[];
    for (final e in _album) {
      for (var i = 0; i < e.photos.length; i++) {
        cells.add(_AlbumCell(entry: e, index: i));
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('${_album.length} 次记录 · ${cells.length} 张照片',
                    style: AppText.sub),
              ),
              TextButton.icon(
                onPressed: _openMemoryWall,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('回忆墙'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpace.sm,
              mainAxisSpacing: AppSpace.sm,
            ),
            itemCount: cells.length,
            itemBuilder: (_, i) {
              final c = cells[i];
              final path = c.entry.photos[c.index];
              return GestureDetector(
                onTap: () => _viewPhoto(c),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.divider,
                          child: const Icon(Icons.broken_image,
                              color: AppColors.textFaint),
                        ),
                      ),
                    ),
                    if (c.index == 0)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(c.entry.date.substring(5),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _viewPhoto(_AlbumCell cell) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(cell.entry.date,
                style: const TextStyle(color: Colors.white)),
          ),
          body: PhotoView(
            imageProvider: FileImage(File(cell.entry.photos[cell.index])),
            heroAttributes:
                PhotoViewHeroAttributes(tag: '${cell.entry.id}_${cell.index}'),
          ),
        ),
      ),
    );
  }

  // ---------------- Tab 5 消费 ----------------

  Widget _spendTab() {
    final now = DateTime.now();
    final equipmentInMonth = _equipments.where((e) {
      if (e.date == null) return false;
      final d = DateTime.tryParse(e.date!);
      return d != null &&
          d.year == now.year &&
          d.month == now.month;
    }).length;

    // 分类汇总（本月 / 本年）
    final catSums = <String, double>{};
    for (final key in kCategoryLabels.keys) {
      catSums[key] = 0;
    }
    bool inRange(DateTime? d) {
      if (d == null) return false;
      if (_range == 'month') {
        return d.year == now.year && d.month == now.month;
      }
      return d.year == now.year;
    }

    for (final r in _records) {
      final d = DateTime.tryParse(r.recordDate);
      if (!inRange(d)) continue;
      final cat = kRecordCategory[r.type] ?? 'other';
      catSums[cat] = (catSums[cat] ?? 0) + (r.cost ?? 0);
    }
    for (final e in _equipments) {
      final d = e.date == null ? null : DateTime.tryParse(e.date!);
      if (!inRange(d)) continue;
      catSums['equipment'] = (catSums['equipment'] ?? 0) + e.price;
    }
    final rangeTotal = catSums.values.fold(0.0, (s, v) => s + v);

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('宠物身价', style: AppText.h3),
              const SizedBox(height: AppSpace.xs),
              Text('为它花的每一笔，都是它的身价',
                  style: AppText.faint),
              const SizedBox(height: AppSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('¥ ${_worth.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                  const SizedBox(width: AppSpace.md),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                        '记录 ¥${_recordsCost.toStringAsFixed(0)} + 装备 ¥${_equipCost.toStringAsFixed(0)}',
                        style: AppText.sub),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_range == 'month' ? '本月消费' : '本年消费',
                      style: AppText.h3)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'month', label: Text('月')),
                      ButtonSegment(value: 'year', label: Text('年')),
                    ],
                    selected: {_range},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (s) =>
                        setState(() => _range = s.first),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text('共 ¥${rangeTotal.toStringAsFixed(0)}',
                  style: AppText.sub),
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                height: 180,
                child: _spendChart(catSums, rangeTotal),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SectionHeader(
          title: '大件装备',
          actionLabel: '添加',
          onAction: _showAddEquipment,
        ),
        const SizedBox(height: AppSpace.sm),
        if (_equipments.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              child: Center(
                child: Text('烘干机、宠物车、喂食器…记在这里',
                    style: AppText.sub),
              ),
            ),
          )
        else
          ..._equipments.map(_equipmentCard),
        if (equipmentInMonth > 0) ...[
          const SizedBox(height: AppSpace.sm),
          Text('本月新增 $equipmentInMonth 件装备', style: AppText.faint),
        ],
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }

  Widget _spendChart(Map<String, double> catSums, double total) {
    final entries = catSums.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Center(child: Text('该时段暂无消费记录', style: AppText.sub));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: entries.first.value * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Text(kCategoryLabels[entries[idx].key] ?? '',
                    style: AppText.faint);
              },
            ),
          ),
        ),
        barGroups: List.generate(entries.length, (i) {
          final e = entries[i];
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: e.value,
              width: 22,
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sm)),
            ),
          ]);
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              '${kCategoryLabels[entries[group.x.round()].key] ?? ''} ¥${rod.toY.toStringAsFixed(0)}',
              const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _equipmentCard(Equipment e) {
    final worthShare = _worth > 0 ? (e.price / _worth * 100) : 0.0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: e.photoPath != null && File(e.photoPath!).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(File(e.photoPath!), fit: BoxFit.cover),
                  )
                : const Center(child: Text('🛍️', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.name,
                          style: AppText.h3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('¥${e.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('为身价贡献 ${worthShare.toStringAsFixed(1)}%',
                    style: AppText.faint),
                if (e.date != null) ...[
                  const SizedBox(height: 2),
                  Text('购于 ${e.date}', style: AppText.faint),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.textFaint,
            onPressed: () async {
              final ok = await showConfirm(context,
                  title: '删除装备？', content: e.name, confirmLabel: '删除');
              if (!ok) return;
              await DatabaseHelper.instance.deleteEquipment(e.id);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEquipment() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    String? photoPath;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpace.lg,
            right: AppSpace.lg,
            top: AppSpace.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpace.lg,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('添加大件装备', style: AppText.h2),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: '装备名称 *'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: '价格 (¥) *'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  GestureDetector(
                    onTap: () async {
                      final d = await showScrollDatePicker(
                        ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setLocal(() => date = d);
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        readOnly: true,
                        controller:
                            TextEditingController(text: date),
                        decoration: const InputDecoration(
                            labelText: '购买日期'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                          if (picked == null) return;
                          final dir = await getApplicationDocumentsDirectory();
                          final eqDir = Directory('${dir.path}/equipments');
                          if (!eqDir.existsSync()) {
                            eqDir.createSync(recursive: true);
                          }
                          final ext =
                              p.extension(picked.path).toLowerCase();
                          final dest = File(
                              '${eqDir.path}/${genId()}$ext');
                          await File(picked.path).copy(dest.path);
                          setLocal(() => photoPath = dest.path);
                        },
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(photoPath == null ? '选照片' : '已选照片'),
                      ),
                      const Expanded(
                          child: SizedBox()),
                      if (photoPath != null)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          child: Image.file(File(photoPath!),
                              width: 44, height: 44, fit: BoxFit.cover),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final price =
                          double.tryParse(priceCtrl.text.trim());
                      if (name.isEmpty || price == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('请填写名称和价格')),
                        );
                        return;
                      }
                      await DatabaseHelper.instance.insertEquipment(
                        Equipment(
                          id: genId(),
                          petId: _pet.id,
                          name: name,
                          price: price,
                          date: date,
                          note:
                              noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                          photoPath: photoPath,
                          createdAt:
                              DateTime.now().millisecondsSinceEpoch,
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('保存装备'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- 页面组装 ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            toolbarHeight: 0,
            backgroundColor: AppColors.primarySoft,
          ),
        ],
        body: Column(
          children: [
            _header(),
            Container(
              color: AppColors.bg,
              child: TabBar(
                controller: _tab,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textFaint,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '档案'),
                  Tab(text: '记录'),
                  Tab(text: '体重'),
                  Tab(text: '相册'),
                  Tab(text: '消费'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _profileTab(),
                  _recordsTab(),
                  _weightTab(),
                  _albumTab(),
                  _spendTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCell {
  final AlbumEntry entry;
  final int index;
  const _AlbumCell({required this.entry, required this.index});
}
