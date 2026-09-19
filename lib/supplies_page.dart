import 'package:flutter/material.dart';

import 'database.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/date_picker_sheet.dart';

/// 用品柜：日常消耗用品的库存展示与入库/消耗记录。
class SuppliesPage extends StatefulWidget {
  final List<Pet> pets; // 供记录消耗时选择宠物（可空场景忽略）
  const SuppliesPage({super.key, this.pets = const []});

  @override
  State<SuppliesPage> createState() => _SuppliesPageState();
}

class _SuppliesPageState extends State<SuppliesPage> {
  List<Supply> _supplies = [];
  Map<String, List<SupplyLog>> _logs = {}; // supplyId -> logs
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supplies = await DatabaseHelper.instance.getSupplies();
    final logs = <String, List<SupplyLog>>{};
    for (final s in supplies) {
      logs[s.id] = await DatabaseHelper.instance.getSupplyLogs(s.id);
    }
    if (!mounted) return;
    setState(() {
      _supplies = supplies;
      _logs = logs;
    });
  }

  // ---------------- 派生数据 ----------------

  List<SupplyLog> logsOf(Supply s) => _logs[s.id] ?? const [];

  /// 最近一次入库的保质期至
  String? latestExpiry(Supply s) {
    final ins = logsOf(s).where((l) => l.type == 'in' && l.expiryDate != null).toList();
    if (ins.isEmpty) return null;
    ins.sort((a, b) => b.date.compareTo(a.date));
    return ins.first.expiryDate;
  }

  /// 累计花费（所有入库金额之和）
  double totalSpent(Supply s) => logsOf(s)
      .where((l) => l.type == 'in')
      .fold(0, (sum, l) => sum + (l.price ?? 0));

  /// 距过期天数（null 表示未知）
  int? daysToExpiry(Supply s) {
    final exp = latestExpiry(s);
    if (exp == null) return null;
    final d = DateTime.tryParse(exp);
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  bool isExpired(Supply s) {
    final d = daysToExpiry(s);
    return d != null && d < 0;
  }

  bool isExpiringSoon(Supply s) {
    final d = daysToExpiry(s);
    return d != null && d >= 0 && d <= 30;
  }

  bool isLowStock(Supply s) => s.quantity > 0 && s.quantity <= 1;

  int get _expiringCount =>
      _supplies.where((s) => isExpired(s) || isExpiringSoon(s)).length;

  double get _totalValue =>
      _supplies.fold(0, (sum, s) => sum + totalSpent(s));

  // ---------------- 操作 ----------------

  Future<void> _addSupply() async {
    await _showSupplyForm();
    _load();
  }

  Future<void> _editSupply(Supply s) async {
    await _showSupplyForm(edit: s);
    _load();
  }

  /// 新建 / 编辑用品基础信息；新建时可同时完成首次入库
  Future<void> _showSupplyForm({Supply? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name);
    final dosageCtrl = TextEditingController(text: edit?.dosageNote);
    final noteCtrl = TextEditingController(text: edit?.note);
    String category = edit?.category ?? 'other';
    String unit = edit?.unit ?? '袋';

    // 首次入库信息（仅新建时）
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    String? prodDate;
    String? expiryDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                    Text(edit == null ? '新增用品' : '编辑用品', style: AppText.h2),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: '用品名称 *'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(labelText: '分类'),
                            items: kSupplyCategories.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                        '${supplyCategoryEmoji(e.key)} ${e.value}')))
                                .toList(),
                            onChanged: (v) =>
                                setLocal(() => category = v ?? 'other'),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: unit,
                            decoration: const InputDecoration(labelText: '单位'),
                            items: kSupplyUnits
                                .map((u) =>
                                    DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) => setLocal(() => unit = v ?? '袋'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextField(
                      controller: dosageCtrl,
                      decoration: const InputDecoration(
                          labelText: '使用剂量说明',
                          hintText: '如：每次半片，一日两次'),
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: '备注'),
                    ),
                    if (edit == null) ...[
                      const Divider(height: AppSpace.xl * 2),
                      const Text('首次入库', style: AppText.h3),
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: '入库数量 *'),
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: '金额 (¥)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextField(
                        controller: channelCtrl,
                        decoration: const InputDecoration(
                            labelText: '购买渠道', hintText: '如：京东 / 淘宝 / 线下宠物店'),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: _dateField('入库日期', date, (d) => date = d,
                                setLocal, allowFuture: false),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: _dateField('生产日期', prodDate,
                                (d) => prodDate = d, setLocal),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      _dateField('保质期至', expiryDate, (d) => expiryDate = d,
                          setLocal),
                    ],
                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('请填写用品名称')));
                          return;
                        }
                        if (edit == null) {
                          final id = genId();
                          await DatabaseHelper.instance.insertSupply(Supply(
                            id: id,
                            name: name,
                            category: category,
                            quantity: 0,
                            unit: unit,
                            dosageNote: dosageCtrl.text.trim().isEmpty
                                ? null
                                : dosageCtrl.text.trim(),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                          ));
                          final qty = double.tryParse(qtyCtrl.text.trim());
                          if (qty != null && qty > 0) {
                            await DatabaseHelper.instance.restockSupply(SupplyLog(
                              id: genId(),
                              supplyId: id,
                              type: 'in',
                              qty: qty,
                              date: date,
                              price: double.tryParse(priceCtrl.text.trim()),
                              channel: channelCtrl.text.trim().isEmpty
                                  ? null
                                  : channelCtrl.text.trim(),
                              prodDate: prodDate,
                              expiryDate: expiryDate,
                              createdAt:
                                  DateTime.now().millisecondsSinceEpoch,
                            ));
                          }
                        } else {
                          await DatabaseHelper.instance.updateSupply(Supply(
                            id: edit.id,
                            name: name,
                            category: category,
                            quantity: edit.quantity,
                            unit: unit,
                            dosageNote: dosageCtrl.text.trim().isEmpty
                                ? null
                                : dosageCtrl.text.trim(),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            createdAt: edit.createdAt,
                          ));
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(edit == null ? '保存并入库' : '保存修改'),
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

  Widget _dateField(String label, String? value, void Function(String) set,
      StateSetter setLocal, {bool allowFuture = true}) {
    return GestureDetector(
      onTap: () async {
        final d = await showScrollDatePicker(
          context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2035),
        );
        if (d != null) {
          set(d);
          setLocal(() {});
        }
      },
      child: AbsorbPointer(
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: value ?? ''),
          decoration: InputDecoration(labelText: label, hintText: '选择'),
        ),
      ),
    );
  }

  Future<void> _restock(Supply s) async {
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    String? prodDate;
    String? expiryDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('入库 · ${s.name}', style: AppText.h2),
                  const SizedBox(height: AppSpace.xs),
                  Text('当前库存 ${_fmt(s.quantity)} ${s.unit}', style: AppText.sub),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: '入库数量 *', suffixText: s.unit),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '金额 (¥)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: channelCtrl,
                    decoration: const InputDecoration(labelText: '购买渠道'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField('入库日期', date, (d) => date = d,
                            setLocal, allowFuture: false),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _dateField('生产日期', prodDate,
                            (d) => prodDate = d, setLocal),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  _dateField(
                      '保质期至', expiryDate, (d) => expiryDate = d, setLocal),
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: () async {
                      final qty = double.tryParse(qtyCtrl.text.trim());
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请填写正确的入库数量')));
                        return;
                      }
                      await DatabaseHelper.instance.restockSupply(SupplyLog(
                        id: genId(),
                        supplyId: s.id,
                        type: 'in',
                        qty: qty,
                        date: date,
                        price: double.tryParse(priceCtrl.text.trim()),
                        channel: channelCtrl.text.trim().isEmpty
                            ? null
                            : channelCtrl.text.trim(),
                        prodDate: prodDate,
                        expiryDate: expiryDate,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('确认入库'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _consume(Supply s) async {
    if (s.quantity <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.name} 已无库存，请先入库')));
      return;
    }
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('消耗 · ${s.name}', style: AppText.h2),
              const SizedBox(height: AppSpace.xs),
              Text('当前库存 ${_fmt(s.quantity)} ${s.unit}', style: AppText.sub),
              if (s.dosageNote != null && s.dosageNote!.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                Text('剂量说明：${s.dosageNote}', style: AppText.sub),
              ],
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: '消耗数量 *',
                    suffixText: s.unit,
                    helperText: '当前最多可消耗 ${_fmt(s.quantity)} ${s.unit}'),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: '备注', hintText: '如：日常喂食 / 换砂'),
              ),
              const SizedBox(height: AppSpace.xl),
              FilledButton(
                onPressed: () async {
                  final qty = double.tryParse(qtyCtrl.text.trim());
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('请填写正确的消耗数量')));
                    return;
                  }
                  await DatabaseHelper.instance.consumeSupply(
                    s.id,
                    qty,
                    date: DateTime.now().toIso8601String().substring(0, 10),
                    note:
                        noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('确认消耗'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLogs(Supply s) async {
    final logs = logsOf(s);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.name} · 出入库流水', style: AppText.h2),
                      const SizedBox(height: AppSpace.xs),
                      Text('共 ${logs.length} 条记录', style: AppText.sub),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(child: Text('暂无出入库记录', style: AppText.sub))
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.all(AppSpace.lg),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final l = logs[i];
                            final isIn = l.type == 'in';
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: AppSpace.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isIn
                                          ? AppColors.done.withValues(alpha: 0.12)
                                          : AppColors.today.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(isIn ? '入' : '耗',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isIn
                                                ? AppColors.done
                                                : AppColors.primaryDark,
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${isIn ? '+' : '-'}${_fmt(l.qty)} ${s.unit}'
                                          '${l.price != null ? ' · ¥${l.price!.toStringAsFixed(0)}' : ''}',
                                          style: AppText.body,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            l.date,
                                            if (l.channel != null) l.channel!,
                                            if (l.expiryDate != null)
                                              '保质期至 ${l.expiryDate}',
                                            if (l.note != null) l.note!,
                                          ].join(' · '),
                                          style: AppText.faint,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (l.recordId != null)
                                    const Icon(Icons.link, size: 16, color: AppColors.textFaint),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _supplies
        : _supplies.where((s) => s.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('用品柜')),
      body: _supplies.isEmpty
          ? EmptyState(
              emoji: '📦',
              title: '用品柜还是空的',
              subtitle: '把猫砂、零食、药品等日常消耗品记进来\n入库、消耗、保质期一目了然',
              actionLabel: '添加第一个用品',
              onAction: _addSupply,
            )
          : Column(
              children: [
                _summaryHeader(),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg, vertical: AppSpace.sm),
                    children: [
                      _filterChip('all', '全部'),
                      ...kSupplyCategories.keys.map((c) => _filterChip(c,
                          '${supplyCategoryEmoji(c)} ${supplyCategoryLabel(c)}')),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('该分类暂无用品', style: AppText.sub))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpace.lg,
                              AppSpace.sm, AppSpace.lg, AppSpace.xl),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _supplyCard(filtered[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSupply,
        icon: const Icon(Icons.add),
        label: const Text('新增用品'),
      ),
    );
  }

  Widget _summaryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            StatTile(label: '在柜品类', value: '${_supplies.length}'),
            StatTile(label: '累计投入', value: '¥${_totalValue.toStringAsFixed(0)}'),
            StatTile(
              label: '临期/过期',
              value: '$_expiringCount',
              color: _expiringCount > 0 ? AppColors.overdue : null,
            ),
            StatTile(
              label: '库存告急',
              value: '${_supplies.where(isLowStock).length}',
              color: _supplies.any(isLowStock) ? AppColors.today : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSub,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }

  Widget _supplyCard(Supply s) {
    final dte = daysToExpiry(s);
    String expiryText;
    Color? expiryColor;
    if (dte == null) {
      expiryText = '保质期未记录';
    } else if (dte < 0) {
      expiryText = '已过期 ${-dte} 天';
      expiryColor = AppColors.overdue;
    } else if (dte <= 30) {
      expiryText = '保质期剩 $dte 天';
      expiryColor = AppColors.today;
    } else {
      expiryText = '保质期至 ${latestExpiry(s)}';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                    child: Text(supplyCategoryEmoji(s.category),
                        style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.name,
                              style: AppText.h3,
                              overflow: TextOverflow.ellipsis),
                        ),
                        StatusChip(
                            text: supplyCategoryLabel(s.category),
                            color: AppColors.primaryDark),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('累计投入 ¥${totalSpent(s).toStringAsFixed(0)}'
                        '${latestExpiry(s) == null ? '' : ' · $expiryText'}',
                        style: TextStyle(
                            fontSize: 12,
                            color: expiryColor ?? AppColors.textFaint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Text(
                _fmt(s.quantity),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: s.quantity <= 0
                      ? AppColors.textFaint
                      : isLowStock(s)
                          ? AppColors.today
                          : AppColors.text,
                ),
              ),
              const SizedBox(width: 4),
              Text(s.unit, style: AppText.sub),
              const Spacer(),
              _pillAction('入库', Icons.add_circle_outline, AppColors.done, () => _restock(s)),
              const SizedBox(width: AppSpace.sm),
              _pillAction('消耗', Icons.remove_circle_outline,
                  AppColors.primaryDark, () => _consume(s)),
            ],
          ),
          if (s.dosageNote != null && s.dosageNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                const Icon(Icons.medication_outlined,
                    size: 14, color: AppColors.textFaint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('剂量：${s.dosageNote}',
                      style: AppText.faint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showLogs(s),
                icon: const Icon(Icons.history, size: 16),
                label: Text('流水 ${logsOf(s).length} 条',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _editSupply(s),
                child: const Text('编辑', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await showConfirm(context,
                      title: '删除用品？',
                      content: '${s.name} 及其全部出入库流水将被删除',
                      confirmLabel: '删除');
                  if (!ok) return;
                  await DatabaseHelper.instance.deleteSupply(s.id);
                  _load();
                },
                child: Text('删除',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.overdue)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
