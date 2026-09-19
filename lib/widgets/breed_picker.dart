import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

/// 品种选择器：内置 10 条主流品种 + 自定义
Future<String?> showBreedPicker(BuildContext context, String species, String? current) async {
  final breeds = kBreeds[species] ?? [];
  final customController = TextEditingController(text: breeds.contains(current) ? '' : (current ?? ''));
  String? selected = breeds.contains(current) ? current : null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: Text('取消', style: TextStyle(color: Colors.grey)),
                      ),
                      Text('选择品种', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          final custom = customController.text.trim();
                          Navigator.pop(c, custom.isNotEmpty ? custom : selected);
                        },
                        child: Text('确定', style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: customController,
                    decoration: InputDecoration(
                      labelText: '自定义品种',
                      hintText: '未在列表中找到可在此输入',
                      prefixIcon: const Icon(Icons.edit),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (_) => setSt(() => selected = null),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('热门品种', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: breeds.length,
                    itemBuilder: (_, i) {
                      final b = breeds[i];
                      final isSel = selected == b && customController.text.trim().isEmpty;
                      return GestureDetector(
                        onTap: () => setSt(() {
                          selected = b;
                          customController.clear();
                        }),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.orange.shade100 : Colors.grey.shade100,
                            border: Border.all(color: isSel ? Colors.orange : Colors.transparent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            b,
                            style: TextStyle(
                              color: isSel ? Colors.orange.shade800 : Colors.black87,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
