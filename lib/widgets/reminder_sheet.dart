import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../theme.dart';
import 'date_picker_sheet.dart';

/// 添加提醒的底部面板，首页快捷操作、提醒中心、宠物详情页共用。
/// [pet] 非空时锁定宠物，否则提供下拉选择。
Future<void> showAddReminderSheet(
  BuildContext context, {
  required List<Pet> pets,
  Pet? pet,
  required VoidCallback onSaved,
}) async {
  if (pets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先添加宠物')),
    );
    return;
  }

  final titleController = TextEditingController();
  Pet selected = pet ?? pets.first;
  String date = DateTime.now().toIso8601String().substring(0, 10);
  String type = 'other';

  const types = {
    'vaccine': '疫苗',
    'deworm': '驱虫',
    'checkup': '体检',
    'medication': '用药',
    'groom': '清洁护理',
    'other': '其他',
  };

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
                const Text('添加提醒', style: AppText.h2),
                const SizedBox(height: AppSpace.lg),
                if (pet == null)
                  DropdownButtonFormField<Pet>(
                    value: selected,
                    decoration: const InputDecoration(labelText: '宠物'),
                    items: pets
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setLocal(() => selected = v ?? selected),
                  ),
                if (pet == null) const SizedBox(height: AppSpace.md),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '提醒内容 *'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: types.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setLocal(() => type = v ?? 'other'),
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
                      controller: TextEditingController(text: date),
                      decoration: InputDecoration(
                        labelText: '到期日',
                        suffixIcon: Icon(Icons.event, color: Colors.orange.shade300),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                FilledButton(
                  onPressed: () async {
                    final t = titleController.text.trim();
                    if (t.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('请填写提醒内容')),
                      );
                      return;
                    }
                    await DatabaseHelper.instance.insertReminder(
                      Reminder(
                        id: genId(),
                        petId: selected.id,
                        title: t,
                        dueDate: date,
                        type: type,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    onSaved();
                  },
                  child: const Text('保存提醒'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
