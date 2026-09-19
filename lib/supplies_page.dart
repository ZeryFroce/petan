import 'package:flutter/material.dart';

import 'database.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/date_picker_sheet.dart';

/// 用品柜：日常消耗用品与硬件设备的库存展示与入库/消耗记录。
///
/// - 同名物品在列表中合并为一张卡片（合计数量 / 合计金额），
///   点「明细」查看每一批录入记录并可对单批操作。
/// - 「复制」按钮快速新增同类物品（生成一批新库存）。
/// - 入库 / 消耗均可关联宠物，入库金额会计入该宠物的身价。
class SuppliesPage extends StatefulWidget {
  final List<Pet> pets; // 供出入库关联宠物选择
  const SuppliesPage({super.key, this.pets = const []});

  @override
  State<SuppliesPage> createState() => _SuppliesPageState();
}

/// 同名物品分组（合并展示）
class _SupplyGroup {
  final String name;
  final List<Supply> items;

  _SupplyGroup(this.name, this.items);

  String get category => items.first.category;
  String get unit => items.first.unit;
  bool get mixedUnits => items.any((s) => s.unit != unit);
  double get totalQty => items.fold(0, (s, e) => s + e.quantity);
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

  /// 按名称分组合并（组内按创建时间倒序）
  List<_SupplyGroup> groupsOf(List<Supply> list) {
    final map = <String, List<Supply>>{};
    for (final s in list) {
      map.putIfAbsent(s.name, () => []).add(s);
    }
    final groups = map.entries.map((e) => _SupplyGroup(e.key, e.value)).toList();
    groups.sort((a, b) {
      final ta = a.items.fold<int>(0, (m, s) => s.createdAt > m ? s.createdAt : m);
      final tb = b.items.fold<int>(0, (m, s) => s.createdAt > m ? s.createdAt : m);
      return tb.compareTo(ta);
    });
    return groups;
  }

  String petName(String? petId) {
    if (petId == null) return '';
    for (final p in widget.pets) {
      if (p.id == petId) return p.name;
    }
    return '宠物';
  }

  String speciesEmojiOf(String petId) {
    for (final p in widget.pets) {
      if (p.id == petId) return speciesEmoji(p.species);
    }
    return '🐾';
  }

  /// 分组累计花费（所有入库金额之和）
  double groupSpent(_SupplyGroup g) => g.items
      .expand(logsOf)
      .where((l) => l.type == 'in')
      .fold(0, (sum, l) => sum + (l.price ?? 0));

  int spentOf(Supply s) => logsOf(s)
      .where((l) => l.type == 'in')
      .fold(0, (sum, l) => sum + (l.price ?? 0).round());

  /// 某物品最近一次入库的保质期至
  String? latestExpiryOf(Supply s) {
    final ins = logsOf(s).where((l) => l.type == 'in' && l.expiryDate != null).toList();
    if (ins.isEmpty) return null;
    ins.sort((a, b) => b.date.compareTo(a.date));
    return ins.first.expiryDate;
  }

  String? latestExpiryOfGroup(_SupplyGroup g) {
    String? latest;
    String? latestDate;
    for (final s in g.items) {
      final exp = latestExpiryOf(s);
      if (exp == null) continue;
      final inDate = logsOf(s)
          .where((l) => l.type == 'in' && l.expiryDate == exp)
          .map((l) => l.date)
          .fold<String>('', (a, b) => b.compareTo(a) > 0 ? b : a);
      if (latest == null || inDate.compareTo(latestDate ?? '') > 0) {
        latest = exp;
        latestDate = inDate;
      }
    }
    return latest;
  }

  int? daysToExpiry(String? exp) {
    if (exp == null) return null;
    final d = DateTime.tryParse(exp);
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  bool isLowStock(Supply s) => s.quantity > 0 && s.quantity <= 1;

  int get _expiringCount {
    int n = 0;
    for (final s in _supplies) {
      final d = daysToExpiry(latestExpiryOf(s));
      if (d != null && d <= 30) n++;
    }
    return n;
  }

  double get _totalValue => _supplies
      .expand(logsOf)
      .where((l) => l.type == 'in')
      .fold(0, (sum, l) => sum + (l.price ?? 0));

  String _dateOf(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String().substring(0, 10);

  // ---------------- 操作 ----------------

  Future<void> _addSupply() async {
    await _showSupplyForm();
    _load();
  }

  Future<void> _editSupply(Supply s) async {
    await _showSupplyForm(edit: s);
    _load();
  }

  /// 复制单个物品：快速生成一批同名新库存（不含流水）
  Future<void> _duplicate(Supply s) async {
    await DatabaseHelper.instance.insertSupply(Supply(
      id: genId(),
      name: s.name,
      category: s.category,
      quantity: 0,
      unit: s.unit,
      dosageNote: s.dosageNote,
      note: s.note,
      petId: s.petId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已复制「${s.name}」，点「入库」补充新一批库存')));
    }
  }

  /// 新建 / 编辑用品基础信息；新建时可同时完成首次入库
  Future<void> _showSupplyForm({Supply? edit}) async {
    final nameCtrl = TextEditingController(text: edit?.name);
    final dosageCtrl = TextEditingController(text: edit?.dosageNote);
    final noteCtrl = TextEditingController(text: edit?.note);
    String category = edit?.category ?? 'other';
    String unit = edit?.unit ?? '袋';
    String? petId = edit?.petId;

    // 首次入库信息（仅新建时）
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    String? prodDate;
    String? expiryDate;
    String? inPetId; // 首次入库关联的宠物

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
                    if (widget.pets.isNotEmpty) ...[
                      _petPicker(
                        label: '归属宠物（计入其身价）',
                        value: petId,
                        onChanged: (v) => setLocal(() => petId = v),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
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
                      Text('首次入库', style: AppText.h3),
                      const SizedBox(height: AppSpace.md),
                      if (widget.pets.isNotEmpty) ...[
                        _petPicker(
                          label: '本次入库关联宠物',
                          value: inPetId,
                          onChanged: (v) => setLocal(() => inPetId = v),
                        ),
                        const SizedBox(height: AppSpace.md),
                      ],
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
                            petId: petId,
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
                              petId: inPetId ?? petId,
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
                            petId: petId,
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

  /// 宠物选择器（含「不关联」），横向胶囊
  Widget _petPicker({
    required String label,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.faint),
        const SizedBox(height: AppSpace.xs),
        Wrap(
          spacing: AppSpace.sm,
          children: [
            ChoiceChip(
              label: const Text('不关联'),
              selected: value == null,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  fontSize: 12,
                  color: value == null ? Colors.white : AppColors.textSub),
              onSelected: (_) => onChanged(null),
            ),
            ...widget.pets.map((p) => ChoiceChip(
                  label: Text('${speciesEmoji(p.species)} ${p.name}'),
                  selected: value == p.id,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      fontSize: 12,
                      color: value == p.id ? Colors.white : AppColors.textSub),
                  onSelected: (_) => onChanged(p.id),
                )),
          ],
        ),
      ],
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

  /// 多批同名物品时选择对哪一批操作。
  /// 返回选中的 Supply；字符串 'new' 表示新增一批；null 表示取消。
  Future<dynamic> _pickEntry(List<Supply> items, String action) async {
    if (items.length == 1) return items.first;
    return showModalBottomSheet<dynamic>(
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
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text('选择要$action的批次 · ${items.first.name}',
                  style: AppText.h3),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length + 1,
                itemBuilder: (_, i) {
                  if (i == items.length) {
                    return ListTile(
                      leading: Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                      title: const Text('新增一批'),
                      onTap: () => Navigator.pop(ctx, 'new'),
                    );
                  }
                  final s = items[i];
                  return ListTile(
                    leading: Text('${_fmt(s.quantity)} ${s.unit}',
                        style: AppText.h3),
                    title: Text('创建于 ${_dateOf(s.createdAt)}',
                        style: AppText.sub),
                    subtitle: s.petId != null
                        ? Text('归属：${petName(s.petId)}', style: AppText.faint)
                        : null,
                    trailing: Text('¥${spentOf(s).toStringAsFixed(0)}',
                        style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
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
    String? petId = s.petId;

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
                    Text('入库 · ${s.name}', style: AppText.h2),
                    const SizedBox(height: AppSpace.xs),
                    Text('当前库存 ${_fmt(s.quantity)} ${s.unit}',
                        style: AppText.sub),
                    const SizedBox(height: AppSpace.lg),
                    if (widget.pets.isNotEmpty) ...[
                      _petPicker(
                        label: '关联宠物（金额计入其身价）',
                        value: petId,
                        onChanged: (v) => setLocal(() => petId = v),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
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
                          petId: petId,
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child: const Text('确认入库'),
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

  Future<void> _consume(Supply s) async {
    if (s.quantity <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s.name} 已无库存，请先入库')));
      return;
    }
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? petId;

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
                    Text('消耗 · ${s.name}', style: AppText.h2),
                    const SizedBox(height: AppSpace.xs),
                    Text('当前库存 ${_fmt(s.quantity)} ${s.unit}',
                        style: AppText.sub),
                    if (s.dosageNote != null && s.dosageNote!.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text('剂量说明：${s.dosageNote}', style: AppText.sub),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    if (widget.pets.isNotEmpty) ...[
                      _petPicker(
                        label: '关联宠物',
                        value: petId,
                        onChanged: (v) => setLocal(() => petId = v),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
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
                      decoration: const InputDecoration(
                          labelText: '备注', hintText: '如：日常喂食 / 换砂'),
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
                          date:
                              DateTime.now().toIso8601String().substring(0, 10),
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                          petId: petId,
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
          ),
        );
      },
    );
  }

  /// 分组明细：展示每一批录入记录，并可对单批操作
  Future<void> _showGroupDetail(_SupplyGroup g) async {
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
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (ctx, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${g.name} · 明细（${g.items.length} 批）',
                          style: AppText.h2),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        '合计 ${_fmt(g.totalQty)} ${g.mixedUnits ? '（单位不同，见各批）' : g.unit}'
                        ' · 累计 ¥${groupSpent(g).toStringAsFixed(0)}',
                        style: AppText.sub,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    itemCount: g.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = g.items[i];
                      final logs = logsOf(s);
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${_fmt(s.quantity)} ${s.unit}',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: s.quantity <= 0
                                            ? AppColors.textFaint
                                            : AppColors.text)),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                      '第 ${i + 1} 批 · ${_dateOf(s.createdAt)}',
                                      style: AppText.faint),
                                ),
                                Text('¥${spentOf(s).toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: AppSpace.sm,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (s.petId != null)
                                  StatusChip(
                                      text: '归属 ${petName(s.petId)}',
                                      color: AppColors.soon),
                                StatusChip(
                                    text: '流水 ${logs.length} 条',
                                    color: AppColors.textSub),
                                _miniAction('看流水', AppColors.textSub,
                                    () => _showLogs(s)),
                                _miniAction('入库', AppColors.done, () async {
                                  Navigator.pop(ctx);
                                  await _restock(s);
                                }),
                                _miniAction('消耗', AppColors.primaryDark,
                                    () async {
                                  Navigator.pop(ctx);
                                  await _consume(s);
                                }),
                                _miniAction('复制', AppColors.soon, () async {
                                  Navigator.pop(ctx);
                                  await _duplicate(s);
                                }),
                                _miniAction('编辑', AppColors.textSub,
                                    () async {
                                  Navigator.pop(ctx);
                                  await _editSupply(s);
                                }),
                                _miniAction('删除', AppColors.overdue,
                                    () async {
                                  Navigator.pop(ctx);
                                  final ok = await showConfirm(context,
                                      title: '删除该批？',
                                      content:
                                          '${s.name}（${_dateOf(s.createdAt)}）及其全部流水将被删除',
                                      confirmLabel: '删除');
                                  if (!ok) return;
                                  await DatabaseHelper.instance
                                      .deleteSupply(s.id);
                                  _load();
                                }),
                              ],
                            ),
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

  Widget _miniAction(String label, Color color, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }

  Future<void> _showLogs(Supply s) async {
    final logs = logsOf(s);
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
                      ? Center(child: Text('暂无出入库记录', style: AppText.sub))
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
                                            if (l.petId != null)
                                              '关联 ${petName(l.petId)}',
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
                                    Icon(Icons.link, size: 16, color: AppColors.textFaint),
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
    final filteredItems = _filter == 'all'
        ? _supplies
        : _supplies.where((s) => s.category == _filter).toList();
    final groups = groupsOf(filteredItems);

    return Scaffold(
      appBar: AppBar(title: const Text('用品柜')),
      body: _supplies.isEmpty
          ? EmptyState(
              emoji: '📦',
              title: '用品柜还是空的',
              subtitle: '把猫砂、零食、药品、设备等日常用品记进来\n入库、消耗、保质期一目了然',
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
                  child: groups.isEmpty
                      ? Center(child: Text('该分类暂无用品', style: AppText.sub))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpace.lg,
                              AppSpace.sm, AppSpace.lg, AppSpace.xl),
                          itemCount: groups.length,
                          itemBuilder: (_, i) => _groupCard(groups[i]),
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
            StatTile(label: '在柜品类', value: '${groupsOf(_supplies).length}'),
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

  Widget _groupCard(_SupplyGroup g) {
    final exp = latestExpiryOfGroup(g);
    final dte = daysToExpiry(exp);
    String? expiryText;
    Color? expiryColor;
    if (dte != null) {
      if (dte < 0) {
        expiryText = '已过期 ${-dte} 天';
        expiryColor = AppColors.overdue;
      } else if (dte <= 30) {
        expiryText = '保质期剩 $dte 天';
        expiryColor = AppColors.today;
      } else {
        expiryText = '保质期至 $exp';
      }
    }

    final petIds = g.items.map((s) => s.petId).whereType<String>().toSet();

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => _showGroupDetail(g),
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
                    child: Text(supplyCategoryEmoji(g.category),
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
                          child: Text(g.name,
                              style: AppText.h3,
                              overflow: TextOverflow.ellipsis),
                        ),
                        StatusChip(
                            text: supplyCategoryLabel(g.category),
                            color: AppColors.primaryDark),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '累计投入 ¥${groupSpent(g).toStringAsFixed(0)}',
                        if (g.items.length > 1) '${g.items.length} 批',
                        if (expiryText != null) expiryText,
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12,
                          color: expiryColor ?? AppColors.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(g.totalQty),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color:
                      g.totalQty <= 0 ? AppColors.textFaint : AppColors.text,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(g.mixedUnits ? '多单位' : g.unit, style: AppText.sub),
              ),
              const Spacer(),
              _pillAction('入库', Icons.add_circle_outline, AppColors.done,
                  () async {
                final picked = await _pickEntry(g.items, '入库');
                if (picked is Supply) await _restock(picked);
                if (picked == 'new') await _addSupply();
              }),
              const SizedBox(width: AppSpace.sm),
              _pillAction('消耗', Icons.remove_circle_outline,
                  AppColors.primaryDark, () async {
                final picked = await _pickEntry(g.items, '消耗');
                if (picked is Supply) await _consume(picked);
              }),
            ],
          ),
          if (petIds.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              children: petIds
                  .map((id) => StatusChip(
                      text: '${speciesEmojiOf(id)} ${petName(id)}',
                      color: AppColors.soon))
                  .toList(),
            ),
          ],
          if (g.items.any((s) =>
              s.dosageNote != null && s.dosageNote!.isNotEmpty)) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Icon(Icons.medication_outlined,
                    size: 14, color: AppColors.textFaint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      '剂量：${g.items.firstWhere((s) => s.dosageNote?.isNotEmpty ?? false).dosageNote}',
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
                onPressed: () => _showGroupDetail(g),
                icon: const Icon(Icons.list_alt, size: 16),
                label: Text('明细 ${g.items.length} 批',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  // 复制最早创建的一批作为模板
                  final template = (g.items.toList()
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
                      .first;
                  await _duplicate(template);
                },
                icon: const Icon(Icons.copy_all_outlined, size: 15),
                label: const Text('复制', style: TextStyle(fontSize: 12)),
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
