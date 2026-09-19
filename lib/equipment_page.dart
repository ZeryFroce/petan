import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'database.dart';
import 'models.dart';
import 'sync_service.dart';
import 'widgets/date_picker_sheet.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  List<Pet> _pets = [];
  Map<String, List<Equipment>> _map = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pets = await DatabaseHelper.instance.getPets();
    final Map<String, List<Equipment>> m = {};
    for (final p in pets) {
      m[p.id] = await DatabaseHelper.instance.getEquipments(p.id);
    }
    if (mounted) {
      setState(() {
        _pets = pets;
        _map = m;
      });
    }
  }

  double petWorth(String petId) => (_map[petId] ?? []).fold<double>(0, (s, e) => s + e.price);

  Future<void> _addEquipment() async {
    if (_pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加宠物')));
      return;
    }
    String petId = _pets.first.id;
    final nameC = TextEditingController();
    final priceC = TextEditingController();
    final noteC = TextEditingController();
    String date = DateTime.now().toIso8601String().substring(0, 10);
    String? photo;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('添加大件设备'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: petId,
                  items: _pets.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setSt(() => petId = v!),
                  decoration: const InputDecoration(labelText: '所属宠物'),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: '设备名称 * (如 烘干机/宠物车/喂食器)')),
                const SizedBox(height: 10),
                TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '价格 (¥) *')),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final eqDir = Directory('${dir.path}/equipments');
                      await eqDir.create(recursive: true);
                      final target = '${eqDir.path}/${genId()}.jpg';
                      final bytes = await picked.readAsBytes();
                      final decoded = img.decodeImage(bytes);
                      if (decoded != null) {
                        final resized = img.copyResize(decoded, width: 800);
                        await File(target).writeAsBytes(img.encodeJpg(resized, quality: 82));
                      } else {
                        await File(target).writeAsBytes(bytes);
                      }
                      setSt(() => photo = target);
                    }
                  },
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: photo != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(photo!), fit: BoxFit.cover))
                        : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => showScrollDatePicker(context, initialDate: date, firstDate: DateTime(1990), lastDate: DateTime(2035)).then((d) {
                    if (  d != null) setSt(() => date = d);
                  }),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(text: date),
                      readOnly: true,
                      decoration: const InputDecoration(labelText: '购买日期', suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFF5A623))),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: '备注')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                final name = nameC.text.trim();
                final price = double.tryParse(priceC.text.trim());
                if (name.isEmpty || price == null) return;
                await DatabaseHelper.instance.insertEquipment(Equipment(
                  id: genId(),
                  petId: petId,
                  name: name,
                  price: price,
                  date: date,
                  note: noteC.text.trim(),
                  photoPath: photo,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ));
                Navigator.pop(c);
                SyncService.syncIfAuto();
                _load();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _map.values.expand((l) => l).fold<double>(0, (s, e) => s + e.price);
    return Scaffold(
      appBar: AppBar(title: const Text('买买买')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.orange.shade100]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: Color(0xFFF5A623), size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('全家宠物身价（装备合计）', style: TextStyle(fontSize: 14, color: Color(0xFF5C4B37))),
                      const SizedBox(height: 4),
                      Text('¥${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFE8854E))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_pets.isEmpty)
            const Center(child: Text('暂无宠物', style: TextStyle(color: Colors.grey)))
          else
            ..._pets.map((p) {
              final list = _map[p.id] ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5C4B37))),
                        const Spacer(),
                        Text('身价 +¥${petWorth(p.id).toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF5A623), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      const Text('暂无设备', style: TextStyle(color: Colors.grey, fontSize: 12))
                    else
                      ...list.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                if (e.photoPath != null && File(e.photoPath!).existsSync())
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.photoPath!), width: 48, height: 48, fit: BoxFit.cover))
                                else
                                  Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('🛒'))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(e.date ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('+¥${e.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF5A623))),
                              ],
                            ),
                          )),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEquipment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
