import 'dart:convert';

class Pet {
  final String id;
  final String name;
  final String species; // 'cat' | 'dog'
  final String? breed;
  final String? birthday; // yyyy-MM-dd
  final String? gender; // male | female | unknown
  final String? neuter; // neutered | intact | unknown
  final String? avatarPath;
  final String? note;
  final int archived; // 1 = 已归档（不再在主流程展示，可恢复）
  final int createdAt;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthday,
    this.gender,
    this.neuter,
    this.avatarPath,
    this.note,
    this.archived = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'species': species,
        'breed': breed,
        'birthday': birthday,
        'gender': gender,
        'neuter': neuter,
        'avatarPath': avatarPath,
        'note': note,
        'archived': archived,
        'createdAt': createdAt,
      };

  factory Pet.fromMap(Map<String, dynamic> m) => Pet(
        id: m['id'] as String,
        name: m['name'] as String,
        species: m['species'] as String,
        breed: m['breed'] as String?,
        birthday: m['birthday'] as String?,
        gender: m['gender'] as String?,
        neuter: m['neuter'] as String?,
        avatarPath: m['avatarPath'] as String?,
        note: m['note'] as String?,
        archived: m['archived'] as int? ?? 0,
        createdAt: m['createdAt'] as int,
      );

  int? get ageMonths {
    if (birthday == null) return null;
    try {
      final b = DateTime.parse(birthday!);
      final now = DateTime.now();
      return (now.year - b.year) * 12 + now.month - b.month;
    } catch (_) {
      return null;
    }
  }

  String? get ageDisplay {
    if (birthday == null) return null;
    final months = ageMonths;
    if (months == null) return null;
    if (months < 12) return '$months个月';
    final years = months ~/ 12;
    final rem = months % 12;
    if (rem == 0) return '$years岁';
    return '$years岁$rem个月';
  }

  /// 宠物年龄换算为近似人类年龄（粗略公式，用于展示）
  int? get humanAge {
    if (birthday == null) return null;
    final months = ageMonths;
    if (months == null) return null;
    if (species == 'dog') {
      // 第一年≈15，第二年≈9，之后每年≈5
      if (months <= 12) return (months * 15 / 12).round();
      if (months <= 24) return 15 + ((months - 12) * 9 / 12).round();
      return 24 + ((months - 24) * 5 / 12).round();
    }
    // 猫：第一年≈15，第二年≈9，之后每年≈4
    if (months <= 12) return (months * 15 / 12).round();
    if (months <= 24) return 15 + ((months - 12) * 9 / 12).round();
    return 24 + ((months - 24) * 4 / 12).round();
  }
}

class HealthRecord {
  final String id;
  final String petId;
  final String type; // vaccine | deworm | checkup | illness | medication | weight | other
  final String title;
  final String recordDate; // yyyy-MM-dd
  final String? vetName;
  final double? cost;
  final double? weightKg;
  final String? notes;
  final String? attachments; // JSON array of paths
  final String? nextDueDate; // yyyy-MM-dd
  final String? reminderId;
  final int createdAt;

  HealthRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.recordDate,
    this.vetName,
    this.cost,
    this.weightKg,
    this.notes,
    this.attachments,
    this.nextDueDate,
    this.reminderId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'type': type,
        'title': title,
        'recordDate': recordDate,
        'vetName': vetName,
        'cost': cost,
        'weightKg': weightKg,
        'notes': notes,
        'attachments': attachments,
        'nextDueDate': nextDueDate,
        'reminderId': reminderId,
        'createdAt': createdAt,
      };

  factory HealthRecord.fromMap(Map<String, dynamic> m) => HealthRecord(
        id: m['id'] as String,
        petId: m['petId'] as String,
        type: m['type'] as String,
        title: m['title'] as String,
        recordDate: m['recordDate'] as String,
        vetName: m['vetName'] as String?,
        cost: m['cost'] as double?,
        weightKg: m['weightKg'] as double?,
        notes: m['notes'] as String?,
        attachments: m['attachments'] as String?,
        nextDueDate: m['nextDueDate'] as String?,
        reminderId: m['reminderId'] as String?,
        createdAt: m['createdAt'] as int,
      );
}

// 大件设备（买买买）：烘干机、宠物车、喂食器等，计入宠物身价
class Equipment {
  final String id;
  final String petId;
  final String name;
  final double price;
  final String? date; // yyyy-MM-dd
  final String? note;
  final String? photoPath;
  final int createdAt;

  Equipment({
    required this.id,
    required this.petId,
    required this.name,
    required this.price,
    this.date,
    this.note,
    this.photoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'name': name,
        'price': price,
        'date': date,
        'note': note,
        'photoPath': photoPath,
        'createdAt': createdAt,
      };

  factory Equipment.fromMap(Map<String, dynamic> m) => Equipment(
        id: m['id'] as String,
        petId: m['petId'] as String,
        name: m['name'] as String,
        price: (m['price'] as num?)?.toDouble() ?? 0,
        date: m['date'] as String?,
        note: m['note'] as String?,
        photoPath: m['photoPath'] as String?,
        createdAt: m['createdAt'] as int,
      );
}

class Reminder {
  final String id;
  final String petId;
  final String title;
  final String dueDate; // yyyy-MM-dd
  final String? repeatRule; // 'P30D' | 'P90D' | 'P365D' | null
  final String type;
  final int done;
  final String? sourceRecordId;
  final int createdAt;

  Reminder({
    required this.id,
    required this.petId,
    required this.title,
    required this.dueDate,
    this.repeatRule,
    required this.type,
    this.done = 0,
    this.sourceRecordId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'title': title,
        'dueDate': dueDate,
        'repeatRule': repeatRule,
        'type': type,
        'done': done,
        'sourceRecordId': sourceRecordId,
        'createdAt': createdAt,
      };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
        id: m['id'] as String,
        petId: m['petId'] as String,
        title: m['title'] as String,
        dueDate: m['dueDate'] as String,
        repeatRule: m['repeatRule'] as String?,
        type: m['type'] as String,
        done: m['done'] as int? ?? 0,
        sourceRecordId: m['sourceRecordId'] as String?,
        createdAt: m['createdAt'] as int,
      );
}

class AlbumEntry {
  final String id;
  final String petId;
  final String date; // yyyy-MM-dd
  final String? note;
  final String photosJson; // JSON array of paths
  final int compressMode; // 0=原图, 1=压缩
  final int editCount; // 已修改次数（每次记录只能修改1次）
  final int createdAt;

  AlbumEntry({
    required this.id,
    required this.petId,
    required this.date,
    this.note,
    required this.photosJson,
    this.compressMode = 0,
    this.editCount = 0,
    required this.createdAt,
  });

  List<String> get photos {
    if (photosJson.isEmpty) return [];
    try {
      return (jsonDecode(photosJson) as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'date': date,
        'note': note,
        'photosJson': photosJson,
        'compressMode': compressMode,
        'editCount': editCount,
        'createdAt': createdAt,
      };

  factory AlbumEntry.fromMap(Map<String, dynamic> m) => AlbumEntry(
        id: m['id'] as String,
        petId: m['petId'] as String,
        date: m['date'] as String,
        note: m['note'] as String?,
        photosJson: m['photosJson'] as String? ?? '[]',
        compressMode: m['compressMode'] as int? ?? 0,
        editCount: m['editCount'] as int? ?? 0,
        createdAt: m['createdAt'] as int,
      );
}

class AppSettings {
  final String? theme; // light | dark | system
  final int lockEnabled;
  final String? lockPin;
  final int bioEnabled; // 指纹/面容解锁开关
  final String? webdavUrl;
  final String? webdavUser;
  final String? webdavPass;
  final String? webdavDir; // 远程目录，结尾不带 /
  final int autoSync;

  AppSettings({
    this.theme,
    this.lockEnabled = 0,
    this.lockPin,
    this.bioEnabled = 0,
    this.webdavUrl,
    this.webdavUser,
    this.webdavPass,
    this.webdavDir,
    this.autoSync = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'theme': theme,
        'lockEnabled': lockEnabled,
        'lockPin': lockPin,
        'bioEnabled': bioEnabled,
        'webdavUrl': webdavUrl,
        'webdavUser': webdavUser,
        'webdavPass': webdavPass,
        'webdavDir': webdavDir,
        'autoSync': autoSync,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        theme: m['theme'] as String?,
        lockEnabled: m['lockEnabled'] as int? ?? 0,
        lockPin: m['lockPin'] as String?,
        bioEnabled: m['bioEnabled'] as int? ?? 0,
        webdavUrl: m['webdavUrl'] as String?,
        webdavUser: m['webdavUser'] as String?,
        webdavPass: m['webdavPass'] as String?,
        webdavDir: m['webdavDir'] as String?,
        autoSync: m['autoSync'] as int? ?? 0,
      );

  bool get webdavConfigured =>
      (webdavUrl?.isNotEmpty ?? false) &&
      (webdavUser?.isNotEmpty ?? false) &&
      (webdavPass?.isNotEmpty ?? false);
}

const kRecordTypeLabels = {
  'vaccine': '疫苗',
  'deworm': '驱虫',
  'checkup': '体检',
  'illness': '疾病就诊',
  'medication': '用药',
  'weight': '体重',
  'feed': '喂食',
  'groom': '清洁护理',
  'other': '其他',
};

const kRecordTypeEmojis = {
  'vaccine': '💉',
  'deworm': '💊',
  'checkup': '🩺',
  'illness': '🤒',
  'medication': '💊',
  'weight': '⚖️',
  'feed': '🍖',
  'groom': '🧼',
  'other': '📝',
};

// 分类字典：用于消费图表与统计
const kCategoryLabels = {
  'medical': '医疗',
  'feed': '喂食',
  'equipment': '装备',
  'supplies': '用品',
  'groom': '清洁',
  'other': '其他',
};

// 记录类型 -> 统计分类
const kRecordCategory = {
  'vaccine': 'medical',
  'deworm': 'medical',
  'checkup': 'medical',
  'illness': 'medical',
  'medication': 'medical',
  'weight': 'other',
  'feed': 'feed',
  'groom': 'groom',
  'other': 'other',
};

// 清洁子类（剃毛、洗澡、剪指甲、清理耳道）
const kGroomLabels = {
  'bath': '洗澡',
  'haircut': '剃毛',
  'nail': '剪指甲',
  'ear': '清理耳道',
  'teeth': '刷牙',
};

// 喂食情况状态
const kFeedStatusLabels = {
  'good': '食欲良好',
  'normal': '正常',
  'poor': '食欲不佳',
};

const kSpeciesLabels = {'cat': '猫咪', 'dog': '狗狗'};

const kSpeciesEmojis = {'cat': '🐱', 'dog': '🐶'};

// 主流品种，按物种分类
const kBreeds = {
  'dog': ['金毛', '柯基', '泰迪', '柴犬', '边牧', '拉布拉多', '哈士奇', '比熊', '博美', '法斗'],
  'cat': ['英短', '美短', '布偶', '暹罗', '缅因', '橘猫', '狸花猫', '蓝猫', '金渐层', '银渐层'],
};

String recordTypeLabel(String t) => kRecordTypeLabels[t] ?? t;
String recordTypeEmoji(String t) => kRecordTypeEmojis[t] ?? '📋';
String speciesLabel(String s) => kSpeciesLabels[s] ?? s;
String speciesEmoji(String s) => kSpeciesEmojis[s] ?? '🐾';

String genId() {
  final now = DateTime.now();
  return '${now.millisecondsSinceEpoch}${(now.microsecond % 1000).toString().padLeft(3, '0')}';
}

List<String>? parseAttachments(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as String).toList();
  } catch (_) {
    return null;
  }
}

String encodeAttachments(List<String>? list) =>
    list == null ? '' : jsonEncode(list);

/// 综合健康评分（10 分制，规则化加减分）
///
/// 兼容旧调用方（首页健康徽章、宠物详情页评分卡）：
/// 使用内置默认规则集计算；健康页使用数据库中的可编辑规则集。
HealthScore computeHealthScore({
  required List<HealthRecord> records,
  required int days,
}) {
  return scoreFromRules(rules: defaultRules(), records: records);
}

class HealthScore {
  final int score; // 0-10
  final String status;
  final int medicalCount; // 生病 + 用药次数
  final int illnessCount;
  final int groomCount;
  final int feedCount;
  final List<String> reasons; // 评分明细
  HealthScore({
    required this.score,
    required this.status,
    required this.medicalCount,
    required this.illnessCount,
    required this.groomCount,
    required this.feedCount,
    this.reasons = const [],
  });
}

// ---------------------------------------------------------------------------
// 用品柜：日常消耗用品（药品、猫砂、零食等）+ 入库/消耗流水
// ---------------------------------------------------------------------------

/// 用品分类
const kSupplyCategories = {
  'drug': '药品',
  'litter': '猫砂/尿垫',
  'snack': '零食',
  'food': '主粮',
  'care': '清洁护理',
  'device': '设备',
  'other': '其他',
};

const kSupplyCategoryEmojis = {
  'drug': '💊',
  'litter': '🧹',
  'snack': '🍪',
  'food': '🥣',
  'care': '🧴',
  'device': '🤖',
  'other': '📦',
};

const kSupplyUnits = ['袋', '包', '瓶', '盒', '罐', '片', '粒', '支', '桶', 'kg', 'ml'];

String supplyCategoryLabel(String c) => kSupplyCategories[c] ?? c;
String supplyCategoryEmoji(String c) => kSupplyCategoryEmojis[c] ?? '📦';

/// 用品：quantity 为当前库存，入库累加、消耗扣减
/// [petId] 为归属宠物（null = 公共用品），入库/消耗可进一步在流水上关联宠物
class Supply {
  final String id;
  final String name;
  final String category; // kSupplyCategories key
  final double quantity; // 当前库存数量
  final String unit; // kSupplyUnits 之一
  final String? dosageNote; // 使用剂量说明
  final String? note;
  final String? petId; // 归属宠物，null = 公共
  final int createdAt;

  Supply({
    required this.id,
    required this.name,
    this.category = 'other',
    this.quantity = 0,
    this.unit = '袋',
    this.dosageNote,
    this.note,
    this.petId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'dosageNote': dosageNote,
        'note': note,
        'petId': petId,
        'createdAt': createdAt,
      };

  factory Supply.fromMap(Map<String, dynamic> m) => Supply(
        id: m['id'] as String,
        name: m['name'] as String,
        category: m['category'] as String? ?? 'other',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        unit: m['unit'] as String? ?? '袋',
        dosageNote: m['dosageNote'] as String?,
        note: m['note'] as String?,
        petId: m['petId'] as String?,
        createdAt: m['createdAt'] as int? ?? 0,
      );
}

/// 用品流水：type = 'in' 入库 | 'out' 消耗
/// 入库时携带 price/channel/prodDate/expiryDate；消耗时可关联健康记录 recordId
class SupplyLog {
  final String id;
  final String supplyId;
  final String type; // in | out
  final double qty;
  final String date; // yyyy-MM-dd
  final double? price; // 入库：购买金额
  final String? channel; // 入库：购买渠道
  final String? prodDate; // 入库：生产日期
  final String? expiryDate; // 入库：保质期至
  final String? note; // 备注 / 使用剂量说明
  final String? recordId; // 消耗关联的健康记录
  final String? petId; // 本次出入库关联的宠物（计入其身价）
  final int createdAt;

  SupplyLog({
    required this.id,
    required this.supplyId,
    required this.type,
    required this.qty,
    required this.date,
    this.price,
    this.channel,
    this.prodDate,
    this.expiryDate,
    this.note,
    this.recordId,
    this.petId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplyId': supplyId,
        'type': type,
        'qty': qty,
        'date': date,
        'price': price,
        'channel': channel,
        'prodDate': prodDate,
        'expiryDate': expiryDate,
        'note': note,
        'recordId': recordId,
        'petId': petId,
        'createdAt': createdAt,
      };

  factory SupplyLog.fromMap(Map<String, dynamic> m) => SupplyLog(
        id: m['id'] as String,
        supplyId: m['supplyId'] as String,
        type: m['type'] as String,
        qty: (m['qty'] as num?)?.toDouble() ?? 0,
        date: m['date'] as String,
        price: (m['price'] as num?)?.toDouble(),
        channel: m['channel'] as String?,
        prodDate: m['prodDate'] as String?,
        expiryDate: m['expiryDate'] as String?,
        note: m['note'] as String?,
        recordId: m['recordId'] as String?,
        petId: m['petId'] as String?,
        createdAt: m['createdAt'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// 健康评分规则：主人可自定义的加减分项（周期打卡型 / 按次计分型）
// ---------------------------------------------------------------------------

/// 规则分类
const kRuleCategories = {
  'checkup': '体检防疫',
  'care': '清洁护理',
  'illness': '生病用药',
  'custom': '自定义',
};

const kRuleCategoryEmojis = {
  'checkup': '🩺',
  'care': '🧼',
  'illness': '🤒',
  'custom': '⭐',
};

String ruleCategoryLabel(String c) => kRuleCategories[c] ?? c;
String ruleCategoryEmoji(String c) => kRuleCategoryEmojis[c] ?? '⭐';

/// 评分规则
/// - [ruleType] = 'periodic' 周期打卡型：periodDays 内有匹配记录 → +bonus，
///   否则 → penalty（penalty 可为 0 表示不扣）
/// - [ruleType] = 'event' 按次计分型：periodDays 内每有一条匹配记录 → +delta
///   （delta 通常为负）
/// - [petId] 为 null 表示全局通用，对所有宠物生效
/// - [matchType] 为记录类型过滤（null/空 = 不限类型）
/// - [keywords] 逗号分隔，匹配记录标题+备注；为空表示仅按类型匹配
class ScoringRule {
  final String id;
  final String? petId; // null = 全局通用
  final String name;
  final String category; // kRuleCategories key
  final String ruleType; // periodic | event
  final double bonus; // periodic：周期内完成加分
  final double penalty; // periodic：超期未完成扣分
  final double delta; // event：每次分值
  final int periodDays; // 统计窗口（天）
  final String? matchType; // 记录类型过滤
  final String keywords; // 逗号分隔关键词
  final int enabled; // 1 = 启用
  final int createdAt;

  ScoringRule({
    required this.id,
    this.petId,
    required this.name,
    this.category = 'custom',
    required this.ruleType,
    this.bonus = 1,
    this.penalty = -1,
    this.delta = -1,
    required this.periodDays,
    this.matchType,
    this.keywords = '',
    this.enabled = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'name': name,
        'category': category,
        'ruleType': ruleType,
        'bonus': bonus,
        'penalty': penalty,
        'delta': delta,
        'periodDays': periodDays,
        'matchType': matchType,
        'keywords': keywords,
        'enabled': enabled,
        'createdAt': createdAt,
      };

  factory ScoringRule.fromMap(Map<String, dynamic> m) => ScoringRule(
        id: m['id'] as String,
        petId: m['petId'] as String?,
        name: m['name'] as String,
        category: m['category'] as String? ?? 'custom',
        ruleType: m['ruleType'] as String? ?? 'periodic',
        bonus: (m['bonus'] as num?)?.toDouble() ?? 1,
        penalty: (m['penalty'] as num?)?.toDouble() ?? -1,
        delta: (m['delta'] as num?)?.toDouble() ?? -1,
        periodDays: (m['periodDays'] as num?)?.toInt() ?? 30,
        matchType: m['matchType'] as String?,
        keywords: m['keywords'] as String? ?? '',
        enabled: m['enabled'] as int? ?? 1,
        createdAt: m['createdAt'] as int? ?? 0,
      );
}

/// 单条规则对评分的贡献
class RuleContribution {
  final ScoringRule rule;
  final double value; // 实际加减分（已乘次数）
  final String reason; // 展示原因，如「洗澡 · 90天内已完成」

  RuleContribution({required this.rule, required this.value, required this.reason});
}

bool _ruleMatchesRecord(ScoringRule rule, HealthRecord r) {
  final mt = rule.matchType;
  if (mt != null && mt.isNotEmpty && r.type != mt) return false;
  final kws = rule.keywords
      .split(',')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty)
      .toList();
  if (kws.isEmpty) return true;
  final hay = '${r.title} ${r.notes ?? ''}';
  return kws.any((k) => hay.contains(k));
}

DateTime? _ruleRecDate(String? s) =>
    (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

/// 按规则集评估记录，返回每条启用规则的贡献（用于展示计算明细）
List<RuleContribution> evaluateRules({
  required List<ScoringRule> rules,
  required List<HealthRecord> records,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final contributions = <RuleContribution>[];
  for (final rule in rules) {
    if (rule.enabled != 1) continue;
    final matched = records.where((r) {
      final d = _ruleRecDate(r.recordDate);
      if (d == null) return false;
      if (d.isBefore(now!.subtract(Duration(days: rule.periodDays)))) return false;
      return _ruleMatchesRecord(rule, r);
    }).toList();

    if (rule.ruleType == 'event') {
      if (matched.isNotEmpty) {
        final v = rule.delta * matched.length;
        contributions.add(RuleContribution(
          rule: rule,
          value: v,
          reason: '${rule.name} ×${matched.length}',
        ));
      }
    } else {
      if (matched.isNotEmpty) {
        if (rule.bonus != 0) {
          contributions.add(RuleContribution(
            rule: rule,
            value: rule.bonus,
            reason: '${rule.name} · ${rule.periodDays}天内已完成',
          ));
        }
      } else if (rule.penalty != 0) {
        contributions.add(RuleContribution(
          rule: rule,
          value: rule.penalty,
          reason: '${rule.periodDays}天未${rule.name}',
        ));
      }
    }
  }
  return contributions;
}

/// 基于规则集计算 HealthScore（score = 10 + Σ贡献，clamp 0~10）
HealthScore scoreFromRules({
  required List<ScoringRule> rules,
  required List<HealthRecord> records,
}) {
  final contributions = evaluateRules(rules: rules, records: records);
  final total = contributions.fold(0.0, (s, c) => s + c.value);
  final score = (10 + total).round().clamp(0, 10);
  String status;
  if (score >= 9) {
    status = '非常健康';
  } else if (score >= 7) {
    status = '健康';
  } else if (score >= 5) {
    status = '一般';
  } else if (score >= 3) {
    status = '不佳';
  } else {
    status = '严重';
  }
  return HealthScore(
    score: score,
    status: status,
    medicalCount: records
        .where((r) => r.type == 'illness' || r.type == 'medication')
        .length,
    illnessCount: records.where((r) => r.type == 'illness').length,
    groomCount: records.where((r) => r.type == 'groom').length,
    feedCount: records.where((r) => r.type == 'feed').length,
    reasons: contributions
        .map((c) =>
            '${c.value > 0 ? '+' : ''}${c.value == c.value.roundToDouble() ? c.value.toStringAsFixed(0) : c.value.toStringAsFixed(1)} ${c.reason}')
        .toList(),
  );
}

/// 默认规则集（建库时播种，全局生效，均可编辑/停用）
List<ScoringRule> defaultRules() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    ScoringRule(id: 'rule-checkup', name: '健康体检', category: 'checkup', ruleType: 'periodic', bonus: 2, penalty: -1, periodDays: 180, matchType: 'checkup', createdAt: now),
    ScoringRule(id: 'rule-vaccine', name: '疫苗', category: 'checkup', ruleType: 'periodic', bonus: 2, penalty: -2, periodDays: 365, matchType: 'vaccine', createdAt: now),
    ScoringRule(id: 'rule-bath', name: '洗澡', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 90, matchType: 'groom', keywords: '洗澡', createdAt: now),
    ScoringRule(id: 'rule-nail', name: '剪指甲', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 30, matchType: 'groom', keywords: '剪指甲,指甲', createdAt: now),
    ScoringRule(id: 'rule-ear', name: '清洁耳道', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 14, matchType: 'groom', keywords: '耳道,耳朵', createdAt: now),
    ScoringRule(id: 'rule-illness', name: '生病就诊', category: 'illness', ruleType: 'event', delta: -3, periodDays: 90, matchType: 'illness', createdAt: now),
    ScoringRule(id: 'rule-medication', name: '用药', category: 'illness', ruleType: 'event', delta: -2, periodDays: 30, matchType: 'medication', createdAt: now),
    ScoringRule(id: 'rule-feed', name: '食欲不佳', category: 'illness', ruleType: 'event', delta: -1, periodDays: 30, matchType: 'feed', keywords: '食欲不佳,poor', createdAt: now),
  ];
}

/// 预设模板库（供健康页一键添加，覆盖用户提到的场景）
List<ScoringRule> presetRules() {
  final now = DateTime.now().millisecondsSinceEpoch;
  List<ScoringRule> mk(List<ScoringRule> list) => list;
  return mk([
    // 体检防疫
    ScoringRule(id: genId(), name: '健康体检', category: 'checkup', ruleType: 'periodic', bonus: 2, penalty: -1, periodDays: 180, matchType: 'checkup', createdAt: now),
    ScoringRule(id: genId(), name: '疫苗', category: 'checkup', ruleType: 'periodic', bonus: 2, penalty: -2, periodDays: 365, matchType: 'vaccine', createdAt: now),
    ScoringRule(id: genId(), name: '驱虫', category: 'checkup', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 30, matchType: 'deworm', createdAt: now),
    // 清洁护理
    ScoringRule(id: genId(), name: '洗澡', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 90, matchType: 'groom', keywords: '洗澡', createdAt: now),
    ScoringRule(id: genId(), name: '剪指甲', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 30, matchType: 'groom', keywords: '剪指甲,指甲', createdAt: now),
    ScoringRule(id: genId(), name: '清洁耳道', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 14, matchType: 'groom', keywords: '耳道,耳朵', createdAt: now),
    ScoringRule(id: genId(), name: '刷牙', category: 'care', ruleType: 'periodic', bonus: 1, penalty: -1, periodDays: 30, matchType: 'groom', keywords: '刷牙', createdAt: now),
    ScoringRule(id: genId(), name: '清洁鼻孔', category: 'care', ruleType: 'periodic', bonus: 1, penalty: 0, periodDays: 14, matchType: 'groom', keywords: '鼻孔,鼻子', createdAt: now),
    ScoringRule(id: genId(), name: '清洁屁股/挤肛门腺', category: 'care', ruleType: 'periodic', bonus: 1, penalty: 0, periodDays: 30, matchType: 'groom', keywords: '屁股,肛门腺', createdAt: now),
    // 生病用药（按次计分）
    ScoringRule(id: genId(), name: '尿闭', category: 'illness', ruleType: 'event', delta: -5, periodDays: 90, matchType: 'illness', keywords: '尿闭,尿不出', createdAt: now),
    ScoringRule(id: genId(), name: '呕吐', category: 'illness', ruleType: 'event', delta: -2, periodDays: 30, matchType: 'illness', keywords: '呕吐,吐', createdAt: now),
    ScoringRule(id: genId(), name: '腹泻/软便', category: 'illness', ruleType: 'event', delta: -2, periodDays: 30, matchType: 'illness', keywords: '腹泻,软便,拉稀', createdAt: now),
    ScoringRule(id: genId(), name: '耳螨', category: 'illness', ruleType: 'event', delta: -3, periodDays: 60, matchType: 'illness', keywords: '耳螨', createdAt: now),
    ScoringRule(id: genId(), name: '感冒/呼吸道', category: 'illness', ruleType: 'event', delta: -2, periodDays: 30, matchType: 'illness', keywords: '感冒,咳嗽,打喷嚏', createdAt: now),
    ScoringRule(id: genId(), name: '皮肤病', category: 'illness', ruleType: 'event', delta: -3, periodDays: 60, matchType: 'illness', keywords: '皮肤病,猫癣,皮炎', createdAt: now),
  ]);
}
