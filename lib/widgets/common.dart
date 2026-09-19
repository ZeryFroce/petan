import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// 提醒状态：首页与提醒中心共用同一套判定与配色，避免两处逻辑不一致
// ---------------------------------------------------------------------------

enum ReminderStatus { overdue, today, soon, done }

/// 距离到期还有几天（负数表示已逾期），按自然日计算。
int daysUntil(String dueDate) {
  final d = DateTime.tryParse(dueDate);
  if (d == null) return 0;
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  return b.difference(a).inDays;
}

ReminderStatus statusOf(Reminder r) {
  if (r.done == 1) return ReminderStatus.done;
  final d = daysUntil(r.dueDate);
  if (d < 0) return ReminderStatus.overdue;
  if (d == 0) return ReminderStatus.today;
  return ReminderStatus.soon;
}

String statusText(Reminder r) {
  switch (statusOf(r)) {
    case ReminderStatus.overdue:
      return '逾期 ${-daysUntil(r.dueDate)} 天';
    case ReminderStatus.today:
      return '今天';
    case ReminderStatus.soon:
      return '${daysUntil(r.dueDate)} 天后';
    case ReminderStatus.done:
      return '已完成';
  }
}

Color statusColor(ReminderStatus s) {
  switch (s) {
    case ReminderStatus.overdue:
      return AppColors.overdue;
    case ReminderStatus.today:
      return AppColors.today;
    case ReminderStatus.soon:
      return AppColors.soon;
    case ReminderStatus.done:
      return AppColors.done;
  }
}

// ---------------------------------------------------------------------------
// 通用组件
// ---------------------------------------------------------------------------

/// 统一卡片：白色圆角 + 柔和投影，支持整卡点击。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpace.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 区块标题，右侧可挂一个文字按钮或自定义组件。
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.h2)),
        if (trailing != null) trailing!,
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// 空状态：emoji 插画 + 说明 + 引导按钮。
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: AppSpace.md),
          Text(title, style: AppText.h3, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(subtitle!, style: AppText.sub, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: 180,
              child: FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 宠物头像：有本地图片则显示，否则用品种 emoji 占位。
class PetAvatar extends StatelessWidget {
  final Pet pet;
  final double size;

  const PetAvatar({super.key, required this.pet, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final path = pet.avatarPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      child: Center(
        child: Text(speciesEmoji(pet.species), style: TextStyle(fontSize: size * 0.55)),
      ),
    );
  }
}

/// 胶囊标签，用于状态、分类等短文本。
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusChip({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 标签-值 一行，用于档案类信息展示。
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: AppText.sub)),
          Expanded(child: Text(value, style: AppText.body)),
        ],
      ),
    );
  }
}

/// 指标方块，用于头部指标条。
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.text,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(unit!, style: AppText.faint),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.faint),
        ],
      ),
    );
  }
}

/// 二次确认弹窗，返回 true 表示确认。
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? content,
  String confirmLabel = '确定',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}
