import 'package:flutter/material.dart';
import 'database.dart';
import 'models.dart';
import 'sync_service.dart';
import 'widgets/date_picker_sheet.dart';

/// 记一笔：新增 / 编辑健康记录。
/// 传入 [record] 时为编辑模式：预填全部字段，保存更新原记录；
/// 新建时可关联用品柜物品，保存后自动扣库存并按单价计入宠物身价。
class AddRecordPage extends StatefulWidget {
  final String petId;
  final VoidCallback onSaved;
  final String? initialType; // 从首页「记体重」等快捷入口进入时预置类型
  final HealthRecord? record; // 非空 = 编辑该记录

  const AddRecordPage({
    super.key,
    required this.petId,
    required this.onSaved,
    this.initialType,
    this.record,
  });

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _title = TextEditingController();
  final _vet = TextEditingController();
  final _cost = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  final _supplyQty = TextEditingController();
  late String _type = widget.initialType ?? 'vaccine';
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  String? _nextDue;
  String _feedStatus = 'normal'; // feed 类型：食欲
  String? _groomSub; // groom 类型：清洁子类
  List<Supply> _supplies = []; // 用品柜在库物品，用于记录消耗
  Supply? _selectedSupply;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    _loadSupplies();
    _prefill();
  }

  void _prefill() {
    final r = widget.record;
    if (r == null) return;
    _type = r.type;
    _date = r.recordDate;
    _nextDue = r.nextDueDate;
    _title.text = r.title;
    _vet.text = r.vetName ?? '';
    _cost.text = r.cost == null ? '' : _trimNum(r.cost!);
    _weight.text = r.weightKg == null ? '' : _trimNum(r.weightKg!);
    // notes 含自动追加的「食欲不佳 / 清洁:xx」前缀，尽量还原控件状态
    String notes = r.notes ?? '';
    if (r.type == 'feed' && notes.contains('食欲不佳')) {
      _feedStatus = 'poor';
      notes = notes.replaceAll('食欲不佳', '').replaceAll('｜', ' ').trim();
    }
    if (r.type == 'groom') {
      final m = RegExp(r'清洁[:：](\S+)').firstMatch(notes);
      if (m != null) {
        final label = m.group(1);
        _groomSub = kGroomLabels.entries
            .where((e) => e.value == label)
            .map((e) => e.key)
            .firstOrNull;
      }
    }
    _notes.text = notes;
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _loadSupplies() async {
    final list = await DatabaseHelper.instance.getSupplies();
    if (!mounted) return;
    setState(() => _supplies = list.where((s) => s.quantity > 0).toList());
  }

  Future<void> _pick(String? initial, void Function(String) set) async {
    final d = await showScrollDatePicker(
      context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2035),
    );
    if (d != null) set(d);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写标题')));
      return;
    }
    String notes = _notes.text.trim();
    if (_type == 'feed' && _feedStatus == 'poor' && !notes.contains('食欲不佳')) {
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}食欲不佳';
    }
    if (_type == 'groom' && _groomSub != null) {
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}清洁:${kGroomLabels[_groomSub] ?? _groomSub}';
    }
    final supplyQty = double.tryParse(_supplyQty.text.trim());
    final useSupply = !_isEdit &&
        _selectedSupply != null &&
        supplyQty != null &&
        supplyQty > 0;
    if (useSupply) {
      final s = _selectedSupply!;
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}消耗用品:${s.name} x${supplyQty}${s.unit}';
    }

    if (_isEdit) {
      final r = widget.record!;
      await DatabaseHelper.instance.updateRecord(HealthRecord(
        id: r.id,
        petId: r.petId,
        type: _type,
        title: title,
        recordDate: _date,
        vetName: _vet.text.trim(),
        cost: _cost.text.isEmpty ? null : double.tryParse(_cost.text),
        weightKg: _type == 'weight' && _weight.text.isNotEmpty
            ? double.tryParse(_weight.text)
            : null,
        notes: notes,
        attachments: r.attachments,
        nextDueDate: _nextDue,
        reminderId: r.reminderId,
        createdAt: r.createdAt,
      ));
      // 到期日变更：重建关联提醒
      if (r.reminderId != null) {
        await DatabaseHelper.instance.deleteReminder(r.reminderId!);
      }
      if (_nextDue != null) {
        await DatabaseHelper.instance.insertReminder(Reminder(
          id: genId(),
          petId: r.petId,
          title: '${recordTypeLabel(_type)}: $title',
          dueDate: _nextDue!,
          type: _type,
          sourceRecordId: r.id,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else {
      final rec = HealthRecord(
        id: genId(),
        petId: widget.petId,
        type: _type,
        title: title,
        recordDate: _date,
        vetName: _vet.text.trim(),
        cost: _cost.text.isEmpty ? null : double.tryParse(_cost.text),
        weightKg: _type == 'weight' && _weight.text.isNotEmpty
            ? double.tryParse(_weight.text)
            : null,
        notes: notes,
        nextDueDate: _nextDue,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await DatabaseHelper.instance.insertRecord(rec);
      if (useSupply) {
        // 消耗自动扣库存；公共用品会按入库单价计价并计入该宠物身价
        await DatabaseHelper.instance.consumeSupply(
          _selectedSupply!.id,
          supplyQty!,
          recordId: rec.id,
          date: _date,
          note: '记录：$title',
          petId: widget.petId,
        );
      }
      if (_nextDue != null) {
        await DatabaseHelper.instance.insertReminder(Reminder(
          id: genId(),
          petId: widget.petId,
          title: '${recordTypeLabel(_type)}: $title',
          dueDate: _nextDue!,
          type: _type,
          sourceRecordId: rec.id,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    widget.onSaved();
    SyncService.syncIfAuto();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑记录' : '添加记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: '类型'),
            items: kRecordTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: '标题 *')),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pick(_date, (v) => setState(() => _date = v)),
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(text: _date),
                readOnly: true,
                decoration: InputDecoration(labelText: '日期', suffixIcon: Icon(Icons.calendar_today, color: Colors.orange.shade300)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _vet, decoration: const InputDecoration(labelText: '医院/医生')),
          const SizedBox(height: 12),
          TextField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '费用 (¥)')),
          if (_type == 'weight') ...[
            const SizedBox(height: 12),
            TextField(controller: _weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '体重 (kg)')),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pick(_nextDue, (v) => setState(() => _nextDue = v)),
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(text: _nextDue ?? ''),
                readOnly: true,
                decoration: InputDecoration(labelText: '下次到期', hintText: '无', suffixIcon: Icon(Icons.event, color: Colors.orange.shade300)),
              ),
            ),
          ),
          if (_type == 'feed') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _feedStatus,
              decoration: const InputDecoration(labelText: '吃饭情况'),
              items: const [
                DropdownMenuItem(value: 'good', child: Text('食欲良好')),
                DropdownMenuItem(value: 'normal', child: Text('正常')),
                DropdownMenuItem(value: 'poor', child: Text('食欲不佳')),
              ],
              onChanged: (v) => setState(() => _feedStatus = v ?? 'normal'),
            ),
          ],
          if (_type == 'groom') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _groomSub,
              decoration: const InputDecoration(labelText: '清洁类型'),
              hint: Text('选择清洁项目'),
              items: kGroomLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _groomSub = v),
            ),
          ],
          // 用品消耗仅在新建时可选（编辑不重复扣库存）
          if (!_isEdit && _supplies.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Supply?>(
              value: _selectedSupply,
              decoration: const InputDecoration(
                labelText: '消耗用品（可选）',
                helperText: '仅显示有库存的物品；保存时自动扣库存并按单价计入身价',
              ),
              hint: Text('不关联用品'),
              items: [
                const DropdownMenuItem<Supply?>(
                  value: null,
                  child: Text('不关联用品', style: TextStyle(color: Colors.grey)),
                ),
                ..._supplies.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                          '${supplyCategoryEmoji(s.category)} ${s.name}（剩余 ${s.quantity.toStringAsFixed(0)} ${s.unit}）'),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedSupply = v),
            ),
          ],
          if (!_isEdit && _selectedSupply != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _supplyQty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '消耗数量 *',
                suffixText: _selectedSupply!.unit,
                helperText: _selectedSupply!.dosageNote == null
                    ? null
                    : '剂量说明：${_selectedSupply!.dosageNote}',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: '备注')),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: Text(_isEdit ? '保存修改' : '保存'))),
        ],
      ),
    );
  }
}
