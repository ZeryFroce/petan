import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 底部弹出滚动式年月日选择器
Future<String?> showScrollDatePicker(
  BuildContext context, {
  String? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime init;
  if (initialDate != null) {
    try {
      init = DateTime.parse(initialDate);
    } catch (_) {
      init = DateTime.now();
    }
  } else {
    init = DateTime.now();
  }

  final first = firstDate ?? DateTime(1990, 1, 1);
  final last = lastDate ?? DateTime.now();

  DateTime selected = init.isBefore(first)
      ? first
      : init.isAfter(last)
          ? last
          : init;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => SafeArea(
        child: SizedBox(
          height: 340,
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
                      child: const Text('取消', style: TextStyle(color: Colors.grey)),
                    ),
                    Text(
                      '${selected.year}年${selected.month}月${selected.day}日',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, selected.toIso8601String().substring(0, 10)),
                      child: const Text('确定', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  minimumDate: first,
                  maximumDate: last,
                  dateOrder: DatePickerDateOrder.ymd,
                  backgroundColor: Colors.white,
                  onDateTimeChanged: (d) => setSt(() => selected = d),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
