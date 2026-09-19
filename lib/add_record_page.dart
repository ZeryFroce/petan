import 'package:flutter/material.dart';
import 'database.dart';
import 'models.dart';
import 'sync_service.dart';
import 'widgets/date_picker_sheet.dart';

class AddRecordPage extends StatefulWidget {
  final String petId;
  final VoidCallback onSaved;
  final String? initialType; // 从首页「记体重」等快捷入口进入时预置类型

  const AddRecordPage({
    super.key,
    required this.petId,
    required this.onSaved,
    this.initialType,
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
  List<Supply> _supplies = []; // 用品柜库存，用于记录消耗
  Supply? _selectedSupply;

  @override
  void initState() {
    super.initState();
    _loadSupplies();
  }

  Future<void> _loadSupplies() async {
    final list = await DatabaseHelper.instance.getSupplies();
    if (!mounted) return;
    setState(() => _supplies = list);
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
    if (_type == 'feed' && _feedStatus == 'poor') {
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}食欲不佳';
    }
    if (_type == 'groom' && _groomSub != null) {
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}清洁:${kGroomLabels[_groomSub] ?? _groomSub}';
    }
    final supplyQty = double.tryParse(_supplyQty.text.trim());
    final useSupply = _selectedSupply != null && supplyQty != null && supplyQty > 0;
    if (useSupply) {
      final s = _selectedSupply!;
      notes = '${notes.isNotEmpty ? '$notes｜' : ''}消耗用品:${s.name} x${supplyQty}${s.unit}';
    }
    final rec = HealthRecord(
      id: genId(),
      petId: widget.petId,
      type: _type,
      title: title,
      recordDate: _date,
      vetName: _vet.text.trim(),
      cost: _cost.text.isEmpty ? null : double.tryParse(_cost.text),
      weightKg: _type == 'weight' && _weight.text.isNotEmpty ? double.tryParse(_weight.text) : null,
      notes: notes,
      nextDueDate: _nextDue,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseHelper.instance.insertRecord(rec);
    if (useSupply) {
      await DatabaseHelper.instance.consumeSupply(
        _selectedSupply!.id,
        supplyQty!,
        recordId: rec.id,
        date: _date,
        note: '记录：$title',
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
    widget.onSaved();
    SyncService.syncIfAuto();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加记录')),
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
              hint: const Text('选择清洁项目'),
              items: kGroomLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _groomSub = v),
            ),
          ],
          if (_supplies.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Supply?>(
              value: _selectedSupply,
              decoration: const InputDecoration(
                labelText: '消耗用品（可选）',
                helperText: '选择后填写消耗数量，保存时自动扣减用品柜库存',
              ),
              hint: const Text('不关联用品'),
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
          if (_selectedSupply != null) ...[
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
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('保存'))),
        ],
      ),
    );
  }
}
