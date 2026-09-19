import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'database.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// 健康总览：规则化健康评分（主人可自定义加减分项与周期）+ 体重趋势曲线。
///
/// 评分计算方式：基础分 10，逐条评估启用的评分规则后加减，结果限制在 0~10。
/// 规则分两类：
/// - 周期打卡型：periodDays 内有匹配记录 → +bonus，否则 → penalty
/// - 按次计分型：periodDays 内每有一条匹配记录 → +delta（通常为负）
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => HealthPageState();
}

class HealthPageState extends State<HealthPage> {
  bool _loading = true;
  List<Pet> _pets = [];
  List<ScoringRule> _rules = [];
  final Map<String, HealthScore> _scores = {};
  final Map<String, List<RuleContribution>> _contributions = {};
  final Map<String, List<HealthRecord>> _weights = {};
  final Map<String, List<HealthRecord>> _recordsByPet = {};
  String? _selectedPetId;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 对指定宠物生效的规则（全局 + 单宠物）
  List<ScoringRule> rulesFor(String petId) => _rules
      .where((r) => r.petId == null || r.petId == petId)
      .toList();

  Future<void> refresh() async {
    final pets = await DatabaseHelper.instance.getPets();
    final rules = await DatabaseHelper.instance.getScoringRules();
    final Map<String, HealthScore> scores = {};
    final Map<String, List<RuleContribution>> contributions = {};
    final Map<String, List<HealthRecord>> weights = {};
    final Map<String, List<HealthRecord>> recordsByPet = {};

    for (final p in pets) {
      final recs = await DatabaseHelper.instance.getRecords(p.id);
      recordsByPet[p.id] = recs;
      final effective = rules
          .where((r) => r.petId == null || r.petId == p.id)
          .toList();
      contributions[p.id] = evaluateRules(rules: effective, records: recs);
      scores[p.id] = scoreFromRules(rules: effective, records: recs);
      final w = recs
          .where((r) => r.type == 'weight' && r.weightKg != null)
          .toList()
        ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
      weights[p.id] = w;
    }

    if (!mounted) return;
    setState(() {
      _pets = pets;
      _rules = rules;
      _scores..clear()..addAll(scores);
      _contributions..clear()..addAll(contributions);
      _weights..clear()..addAll(weights);
      _recordsByPet..clear()..addAll(recordsByPet);
      _selectedPetId ??= pets.isNotEmpty ? pets.first.id : null;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
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

  String _fmtValue(double v) => v == v.roundToDouble()
      ? (v > 0 ? '+${v.toStringAsFixed(0)}' : v.toStringAsFixed(0))
      : (v > 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1));

  // ---------------- 规则管理 ----------------

  Future<void> _openRuleManager() => _showRuleListSheet();

  /// 规则列表弹层：全部规则 + 添加入口（预设模板 / 自定义）
  Future<void> _showRuleListSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, controller) {
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                final scopeName = (String? petId) {
                  if (petId == null) return '全局';
                  for (final p in _pets) {
                    if (p.id == petId) return p.name;
                  }
                  return '未知宠物';
                };

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('评分规则管理', style: AppText.h2),
                                const SizedBox(height: 2),
                                Text('规则即改即生效，评分实时重算', style: AppText.faint),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await _showPresetSheet();
                              await refresh();
                              setSheet(() {});
                            },
                            icon: const Icon(Icons.playlist_add, size: 18),
                            label: Text('添加'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _rules.isEmpty
                          ? Center(
                              child: Text('暂无规则，点击「添加」使用预设模板',
                                  style: AppText.sub))
                          : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.all(AppSpace.lg),
                              itemCount: _rules.length,
                              itemBuilder: (_, i) {
                                final r = _rules[i];
                                return _ruleRow(r, scopeName(r.petId), setSheet);
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _ruleRow(ScoringRule r, String scope, StateSetter setSheet) {
    final desc = r.ruleType == 'periodic'
        ? '${r.periodDays}天内完成 ${_fmtValue(r.bonus)} · 未完成 ${_fmtValue(r.penalty)}'
        : '每次 ${_fmtValue(r.delta)} · ${r.periodDays}天内有效';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: () async {
          await _showRuleForm(edit: r);
          await refresh();
          setSheet(() {});
        },
        child: Row(
          children: [
            Text(ruleCategoryEmoji(r.category),
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: AppText.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      StatusChip(
                        text: r.ruleType == 'periodic' ? '周期打卡' : '按次计分',
                        color: r.ruleType == 'periodic'
                            ? AppColors.soon
                            : AppColors.overdue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: AppText.faint),
                  const SizedBox(height: 2),
                  Text(
                    '作用：$scope'
                    '${(r.matchType == null || r.matchType!.isEmpty) ? '' : ' · 类型：${recordTypeLabel(r.matchType!)}'}'
                    '${r.keywords.isEmpty ? '' : ' · 关键词：${r.keywords}'}',
                    style: AppText.faint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: r.enabled == 1,
              activeThumbColor: AppColors.primary,
              onChanged: (v) async {
                await DatabaseHelper.instance.updateScoringRule(
                  ScoringRule(
                    id: r.id,
                    petId: r.petId,
                    name: r.name,
                    category: r.category,
                    ruleType: r.ruleType,
                    bonus: r.bonus,
                    penalty: r.penalty,
                    delta: r.delta,
                    periodDays: r.periodDays,
                    matchType: r.matchType,
                    keywords: r.keywords,
                    enabled: v ? 1 : 0,
                    createdAt: r.createdAt,
                  ),
                );
                await refresh();
                setSheet(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 预设模板选择弹层：建议值一键添加 + 自定义入口
  Future<void> _showPresetSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, controller) {
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                final presets = presetRules();
                final groups = <String, List<ScoringRule>>{};
                for (final r in presets) {
                  groups.putIfAbsent(r.category, () => []).add(r);
                }

                String desc(ScoringRule r) => r.ruleType == 'periodic'
                    ? '${r.periodDays}天内完成 +${r.bonus.toStringAsFixed(0)}'
                      '，未完成 ${r.penalty == 0 ? '不扣分' : r.penalty.toStringAsFixed(0)}'
                    : '每出现一次 ${r.delta.toStringAsFixed(0)} 分（${r.periodDays}天内）';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('添加评分规则', style: AppText.h2),
                          const SizedBox(height: 2),
                          Text('以下为建议值，添加后可继续调整分值与周期',
                              style: AppText.faint),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(AppSpace.lg),
                        children: [
                          ListTile(
                            leading:
                                Text('⭐', style: TextStyle(fontSize: 22)),
                            title: Text('自定义规则', style: AppText.h3),
                            subtitle: Text('完全自定义名称、分值、周期与匹配方式',
                                style: AppText.faint),
                            trailing: Icon(Icons.chevron_right,
                                color: AppColors.textFaint),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _showRuleForm();
                              await refresh();
                            },
                          ),
                          const Divider(),
                          for (final cat in groups.keys) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.sm),
                              child: Text(
                                  '${ruleCategoryEmoji(cat)} ${ruleCategoryLabel(cat)}',
                                  style: AppText.h3),
                            ),
                            ...groups[cat]!.map((r) {
                              final duplicated =
                                  _rules.any((e) => e.name == r.name);
                              return ListTile(
                                title: Text(r.name, style: AppText.body),
                                subtitle: Text(desc(r), style: AppText.faint),
                                trailing: duplicated
                                    ? StatusChip(
                                        text: '已添加', color: AppColors.done)
                                    : Icon(Icons.add_circle_outline,
                                        color: AppColors.primary),
                                onTap: duplicated
                                    ? null
                                    : () async {
                                        await DatabaseHelper.instance
                                            .insertScoringRule(r);
                                        await refresh();
                                        setSheet(() {});
                                      },
                              );
                            }),
                            const Divider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// 规则编辑弹层：新建 / 编辑
  Future<void> _showRuleForm({ScoringRule? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name);
    final keywordsCtrl = TextEditingController(text: edit?.keywords);
    final periodCtrl = TextEditingController(
        text: edit?.periodDays.toString() ?? '30');
    final bonusCtrl =
        TextEditingController(text: edit?.bonus.toStringAsFixed(0) ?? '1');
    final penaltyCtrl =
        TextEditingController(text: edit?.penalty.toStringAsFixed(0) ?? '-1');
    final deltaCtrl =
        TextEditingController(text: edit?.delta.toStringAsFixed(0) ?? '-1');

    String category = edit?.category ?? 'custom';
    String ruleType = edit?.ruleType ?? 'periodic';
    String? matchType = edit?.matchType;
    String? petId = edit?.petId;
    bool enabled = (edit?.enabled ?? 1) == 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(edit == null ? '自定义规则' : '编辑规则',
                              style: AppText.h2),
                        ),
                        if (edit != null)
                          TextButton(
                            onPressed: () async {
                              final ok = await showConfirm(context,
                                  title: '删除规则？',
                                  content: '「${edit.name}」将不再参与评分',
                                  confirmLabel: '删除');
                              if (!ok) return;
                              await DatabaseHelper.instance
                                  .deleteScoringRule(edit.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text('删除',
                                style: TextStyle(color: AppColors.overdue)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: '规则名称 *'),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration:
                                const InputDecoration(labelText: '分类'),
                            items: kRuleCategories.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                        '${ruleCategoryEmoji(e.key)} ${e.value}')))
                                .toList(),
                            onChanged: (v) =>
                                setLocal(() => category = v ?? 'custom'),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: petId,
                            decoration: const InputDecoration(
                                labelText: '作用宠物'),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('全局通用')),
                              ..._pets.map((p) => DropdownMenuItem(
                                  value: p.id, child: Text(p.name))),
                            ],
                            onChanged: (v) => setLocal(() => petId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'periodic',
                            label: Text('周期打卡'),
                            icon: Icon(Icons.repeat, size: 16)),
                        ButtonSegment(
                            value: 'event',
                            label: Text('按次计分'),
                            icon: Icon(Icons.repeat_one, size: 16)),
                      ],
                      selected: {ruleType},
                      onSelectionChanged: (s) =>
                          setLocal(() => ruleType = s.first),
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextField(
                      controller: periodCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '统计周期（天）*'),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      children: [14, 30, 90, 180, 365]
                          .map((d) => ActionChip(
                                label: Text('$d天'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setLocal(() => periodCtrl.text = '$d'),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (ruleType == 'periodic') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bonusCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: '周期内完成加分',
                                  helperText: '如 +1'),
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: TextField(
                              controller: penaltyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: '超期未完成扣分',
                                  helperText: '0 表示不扣'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: deltaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: '每次出现分值 *',
                            helperText: '扣分填负数，如 -2'),
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    DropdownButtonFormField<String?>(
                      value: matchType,
                      decoration: const InputDecoration(
                          labelText: '匹配的记录类型',
                          helperText: '该规则统计哪类健康记录'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('不限类型')),
                        ...kRecordTypeLabels.entries.map((e) =>
                            DropdownMenuItem(
                                value: e.key, child: Text(e.value))),
                      ],
                      onChanged: (v) => setLocal(() => matchType = v),
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextField(
                      controller: keywordsCtrl,
                      decoration: const InputDecoration(
                        labelText: '关键词（可选）',
                        hintText: '逗号分隔，如：耳道,耳朵；留空则统计该类型全部记录',
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('启用该规则', style: AppText.body),
                      value: enabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setLocal(() => enabled = v),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final periodDays =
                            int.tryParse(periodCtrl.text.trim());
                        if (name.isEmpty || periodDays == null || periodDays <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('请填写名称和有效的周期天数')));
                          return;
                        }
                        final rule = ScoringRule(
                          id: edit?.id ?? genId(),
                          petId: petId,
                          name: name,
                          category: category,
                          ruleType: ruleType,
                          bonus:
                              double.tryParse(bonusCtrl.text.trim()) ?? 1,
                          penalty:
                              double.tryParse(penaltyCtrl.text.trim()) ?? -1,
                          delta:
                              double.tryParse(deltaCtrl.text.trim()) ?? -1,
                          periodDays: periodDays,
                          matchType: matchType,
                          keywords: keywordsCtrl.text.trim(),
                          enabled: enabled ? 1 : 0,
                          createdAt: edit?.createdAt ??
                              DateTime.now().millisecondsSinceEpoch,
                        );
                        if (edit == null) {
                          await DatabaseHelper.instance
                              .insertScoringRule(rule);
                        } else {
                          await DatabaseHelper.instance
                              .updateScoringRule(rule);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child:
                          Text(edit == null ? '创建规则' : '保存修改'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpace.lg,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('健康', style: AppText.h1),
            const SizedBox(height: 2),
            Text(
              '基础分 10 · ${_rules.where((r) => r.enabled == 1).length} 条规则动态加减 · 点击规则卡查看计算方式',
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
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
                children: [
                  if (_pets.isEmpty)
                    AppCard(
                      child: EmptyState(
                        emoji: '🩺',
                        title: '还没有宠物',
                        subtitle: '添加宠物后即可查看健康评分与趋势',
                      ),
                    )
                  else ...[
                    const SectionHeader(title: '健康评分'),
                    const SizedBox(height: AppSpace.md),
                    ..._pets.map(_scoreCard),
                    const SizedBox(height: AppSpace.xl),
                    SectionHeader(
                      title: '评分规则',
                      trailing: Row(
                        children: [
                          Text('${_rules.length} 条', style: AppText.faint),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.tune, size: 20),
                            color: AppColors.primaryDark,
                            tooltip: '管理规则',
                            onPressed: _openRuleManager,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _rulesHintCard(),
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader(title: '体重趋势'),
                    const SizedBox(height: AppSpace.md),
                    _weightSection(),
                  ],
                ],
              ),
            ),
    );
  }

  /// 规则速览卡：展示加减分逻辑说明，点击进入管理
  Widget _rulesHintCard() {
    return AppCard(
      onTap: _openRuleManager,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计算方式', style: AppText.h3),
          const SizedBox(height: AppSpace.sm),
          Text(
            '健康分 = 基础分 10 + 各规则加减分（限 0~10 分）。'
            '「周期打卡」规则在周期内完成加分、超期未完成扣分；'
            '「按次计分」规则按周期内出现次数累计加减。',
            style: AppText.sub,
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: _rules
                .take(6)
                .map((r) => StatusChip(
                      text: r.ruleType == 'periodic'
                          ? '${r.name} ${r.periodDays}天'
                          : '${r.name} 每次${_fmtValue(r.delta)}',
                      color: AppColors.textSub,
                    ))
                .toList(),
          ),
          if (_rules.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text('还有 ${_rules.length - 6} 条规则，点击查看全部', style: AppText.faint),
            ),
        ],
      ),
    );
  }

  Widget _scoreCard(Pet p) {
    final hs = _scores[p.id];
    if (hs == null) return const SizedBox.shrink();
    final color = _statusColor(hs.status);
    final contributions = _contributions[p.id] ?? const [];
    final positives = contributions.where((c) => c.value > 0).length;
    final negatives = contributions.where((c) => c.value < 0).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: hs.score / 10,
                          strokeWidth: 7,
                          backgroundColor: AppColors.primarySoft,
                          color: color,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${hs.score}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                          Text('/10', style: AppText.faint),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.name, style: AppText.h3)),
                          StatusChip(text: hs.status, color: color),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        '医疗 ${hs.medicalCount} · 清洁 ${hs.groomCount} · 喂食 ${hs.feedCount}',
                        style: AppText.faint,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        '计算方式：10 + 加分 $positives 项 − 扣分 $negatives 项',
                        style: AppText.sub,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpace.md),
            if (contributions.isEmpty)
              Text('暂无生效的加减分项', style: AppText.faint)
            else
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: contributions.map((c) {
                  final v = c.value;
                  return StatusChip(
                    text:
                        '${_fmtValue(v)} ${c.reason}',
                    color: v > 0 ? AppColors.done : AppColors.overdue,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weightSection() {
    if (_pets.isEmpty) return const SizedBox.shrink();
    final selected = _selectedPetId;
    final list = _weights[selected] ?? [];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pets.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _pets
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: ChoiceChip(
                          label: Text(p.name),
                          selected: p.id == selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                          labelStyle: TextStyle(
                            color: p.id == selected ? Colors.white : AppColors.textSub,
                            fontSize: 13,
                          ),
                          onSelected: (_) => setState(() => _selectedPetId = p.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_pets.length > 1) const SizedBox(height: AppSpace.md),
          if (list.length < 2)
            const Center(
              child: EmptyState(
                emoji: '⚖️',
                title: '体重数据不足',
                subtitle: '至少记录 2 次体重才能绘制趋势曲线',
              ),
            )
          else ...[
            SizedBox(height: 200, child: _chart(list)),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                StatTile(
                  label: '当前',
                  value: list.last.weightKg!.toStringAsFixed(1),
                  unit: 'kg',
                ),
                StatTile(
                  label: '变化',
                  value: _deltaText(list),
                  unit: 'kg',
                  color: _deltaColor(list),
                ),
                StatTile(label: '记录', value: '${list.length}', unit: '次'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _deltaText(List<HealthRecord> list) {
    final d = list.last.weightKg! - list.first.weightKg!;
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}';
  }

  Color _deltaColor(List<HealthRecord> list) {
    final d = list.last.weightKg! - list.first.weightKg!;
    if (d > 0.3) return AppColors.overdue;
    if (d < -0.3) return AppColors.soon;
    return AppColors.done;
  }

  Widget _chart(List<HealthRecord> list) {
    final spots = list
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weightKg!))
        .toList();
    final values = list.map((e) => e.weightKg!).toList();
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = (hi - lo) == 0 ? 1.0 : (hi - lo) * 0.3;

    return LineChart(
      LineChartData(
        minY: lo - pad,
        maxY: hi + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (hi - lo + pad * 2) / 4,
          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, meta) => Text(
                v.toStringAsFixed(1),
                style: TextStyle(fontSize: 10, color: AppColors.textFaint),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: list.length > 6 ? (list.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= list.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    list[i].recordDate.substring(5),
                    style: TextStyle(fontSize: 10, color: AppColors.textFaint),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: list.length <= 12,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
