import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'pet_health.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await _createTables(db);
        await db.insert('settings', {'id': 1, 'lockEnabled': 0, 'bioEnabled': 0});
        await _seedDefaultRules(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE settings ADD COLUMN webdavUrl TEXT');
          await db.execute('ALTER TABLE settings ADD COLUMN webdavUser TEXT');
          await db.execute('ALTER TABLE settings ADD COLUMN webdavPass TEXT');
          await db.execute('ALTER TABLE settings ADD COLUMN webdavDir TEXT');
          await db.execute('ALTER TABLE settings ADD COLUMN autoSync INTEGER DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE settings ADD COLUMN bioEnabled INTEGER DEFAULT 0');
          await _createAlbumTable(db);
        }
        if (oldVersion < 4) {
          await _createEquipmentTable(db);
        }
        if (oldVersion < 5) {
          await _createSupplyTables(db);
        }
        if (oldVersion < 6) {
          await _createScoringRuleTable(db);
          await _seedDefaultRules(db);
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE pets ADD COLUMN archived INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE supplies ADD COLUMN petId TEXT');
          await db.execute('ALTER TABLE supply_logs ADD COLUMN petId TEXT');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE pets(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT,
        birthday TEXT,
        gender TEXT,
        neuter TEXT,
        avatarPath TEXT,
        note TEXT,
        archived INTEGER DEFAULT 0,
        createdAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE records(
        id TEXT PRIMARY KEY,
        petId TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        recordDate TEXT NOT NULL,
        vetName TEXT,
        cost REAL,
        weightKg REAL,
        notes TEXT,
        attachments TEXT,
        nextDueDate TEXT,
        reminderId TEXT,
        createdAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE reminders(
        id TEXT PRIMARY KEY,
        petId TEXT NOT NULL,
        title TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        repeatRule TEXT,
        type TEXT,
        done INTEGER DEFAULT 0,
        sourceRecordId TEXT,
        createdAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY,
        theme TEXT,
        lockEnabled INTEGER DEFAULT 0,
        lockPin TEXT,
        bioEnabled INTEGER DEFAULT 0,
        webdavUrl TEXT,
        webdavUser TEXT,
        webdavPass TEXT,
        webdavDir TEXT,
        autoSync INTEGER DEFAULT 0
      )
    ''');
    await _createAlbumTable(db);
    await _createEquipmentTable(db);
    await _createSupplyTables(db);
    await _createScoringRuleTable(db);
  }

  Future<void> _createScoringRuleTable(Database db) async {
    await db.execute('''
      CREATE TABLE scoring_rules(
        id TEXT PRIMARY KEY,
        petId TEXT,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'custom',
        ruleType TEXT DEFAULT 'periodic',
        bonus REAL DEFAULT 1,
        penalty REAL DEFAULT -1,
        delta REAL DEFAULT -1,
        periodDays INTEGER DEFAULT 30,
        matchType TEXT,
        keywords TEXT DEFAULT '',
        enabled INTEGER DEFAULT 1,
        createdAt INTEGER
      )
    ''');
  }

  /// 播种默认规则（仅当表为空时，幂等）
  Future<void> _seedDefaultRules(Database db) async {
    final rows = await db.query('scoring_rules');
    if (rows.isNotEmpty) return;
    for (final r in defaultRules()) {
      await db.insert('scoring_rules', r.toMap());
    }
  }

  Future<void> _createAlbumTable(Database db) async {
    await db.execute('''
      CREATE TABLE album(
        id TEXT PRIMARY KEY,
        petId TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        photosJson TEXT NOT NULL,
        compressMode INTEGER DEFAULT 0,
        editCount INTEGER DEFAULT 0,
        createdAt INTEGER,
        UNIQUE(petId, date)
      )
    ''');
  }

  Future<void> _createEquipmentTable(Database db) async {
    await db.execute('''
      CREATE TABLE equipments(
        id TEXT PRIMARY KEY,
        petId TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        date TEXT,
        note TEXT,
        photoPath TEXT,
        createdAt INTEGER
      )
    ''');
  }

  Future<void> _createSupplyTables(Database db) async {
    await db.execute('''
      CREATE TABLE supplies(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT DEFAULT 'other',
        quantity REAL DEFAULT 0,
        unit TEXT DEFAULT '袋',
        dosageNote TEXT,
        note TEXT,
        petId TEXT,
        createdAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE supply_logs(
        id TEXT PRIMARY KEY,
        supplyId TEXT NOT NULL,
        type TEXT NOT NULL,
        qty REAL NOT NULL,
        date TEXT NOT NULL,
        price REAL,
        channel TEXT,
        prodDate TEXT,
        expiryDate TEXT,
        note TEXT,
        recordId TEXT,
        petId TEXT,
        createdAt INTEGER
      )
    ''');
  }

  // Pet
  Future<int> insertPet(Pet p) => database.then((d) => d.insert('pets', p.toMap()));

  /// 默认只返回未归档宠物；[includeArchived] = true 时返回全部
  Future<List<Pet>> getPets({bool includeArchived = false}) async {
    final d = await database;
    final rows = await d.query('pets',
        where: includeArchived ? null : 'archived=0',
        orderBy: 'createdAt DESC');
    return rows.map(Pet.fromMap).toList();
  }

  /// 已归档宠物列表
  Future<List<Pet>> getArchivedPets() async {
    final d = await database;
    final rows = await d.query('pets', where: 'archived=1', orderBy: 'createdAt DESC');
    return rows.map(Pet.fromMap).toList();
  }

  Future<int> setPetArchived(String id, int archived) =>
      database.then((d) => d.update('pets', {'archived': archived},
          where: 'id=?', whereArgs: [id]));

  /// 清空某宠物的全部业务数据（档案本身保留），用于重新录入。
  /// 返回删除的记录条数。
  Future<int> clearPetData(String petId) async {
    final d = await database;
    int n = 0;
    await d.transaction((txn) async {
      n += await txn.delete('records', where: 'petId=?', whereArgs: [petId]);
      n += await txn.delete('reminders', where: 'petId=?', whereArgs: [petId]);
      n += await txn.delete('album', where: 'petId=?', whereArgs: [petId]);
      n += await txn.delete('equipments', where: 'petId=?', whereArgs: [petId]);
      n += await txn.delete('supply_logs', where: 'petId=?', whereArgs: [petId]);
      n += await txn.delete('scoring_rules', where: 'petId=?', whereArgs: [petId]);
      // 该宠物专属（有归属）的用品一并清除；公共用品保留
      final own = await txn.query('supplies',
          columns: ['id'], where: 'petId=?', whereArgs: [petId]);
      for (final row in own) {
        final sid = row['id'] as String;
        n += await txn.delete('supply_logs', where: 'supplyId=?', whereArgs: [sid]);
        n += await txn.delete('supplies', where: 'id=?', whereArgs: [sid]);
      }
    });
    return n;
  }

  Future<Pet?> getPet(String id) async {
    final d = await database;
    final rows = await d.query('pets', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Pet.fromMap(rows.first);
  }
  Future<int> updatePet(Pet p) =>
      database.then((d) => d.update('pets', p.toMap(), where: 'id=?', whereArgs: [p.id]));
  Future<int> deletePet(String id) async {
    final d = await database;
    await d.delete('records', where: 'petId=?', whereArgs: [id]);
    await d.delete('reminders', where: 'petId=?', whereArgs: [id]);
    await d.delete('album', where: 'petId=?', whereArgs: [id]);
    await d.delete('equipments', where: 'petId=?', whereArgs: [id]);
    return d.delete('pets', where: 'id=?', whereArgs: [id]);
  }

  // Equipments
  Future<int> insertEquipment(Equipment e) =>
      database.then((d) => d.insert('equipments', e.toMap()));
  Future<List<Equipment>> getEquipments(String petId) async {
    final d = await database;
    final rows = await d.query('equipments', where: 'petId=?', whereArgs: [petId], orderBy: 'createdAt DESC');
    return rows.map(Equipment.fromMap).toList();
  }
  Future<int> updateEquipment(Equipment e) =>
      database.then((d) => d.update('equipments', e.toMap(), where: 'id=?', whereArgs: [e.id]));
  Future<int> deleteEquipment(String id) =>
      database.then((d) => d.delete('equipments', where: 'id=?', whereArgs: [id]));

  // Supplies（用品柜）
  Future<int> insertSupply(Supply s) =>
      database.then((d) => d.insert('supplies', s.toMap()));
  Future<List<Supply>> getSupplies() async {
    final d = await database;
    final rows = await d.query('supplies', orderBy: 'createdAt DESC');
    return rows.map(Supply.fromMap).toList();
  }
  Future<Supply?> getSupply(String id) async {
    final d = await database;
    final rows = await d.query('supplies', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Supply.fromMap(rows.first);
  }
  Future<int> updateSupply(Supply s) =>
      database.then((d) => d.update('supplies', s.toMap(), where: 'id=?', whereArgs: [s.id]));
  Future<int> deleteSupply(String id) async {
    final d = await database;
    await d.delete('supply_logs', where: 'supplyId=?', whereArgs: [id]);
    return d.delete('supplies', where: 'id=?', whereArgs: [id]);
  }

  /// 入库：写流水 + 库存累加（事务）
  Future<void> restockSupply(SupplyLog log) async {
    final d = await database;
    await d.transaction((txn) async {
      await txn.insert('supply_logs', log.toMap());
      await txn.rawUpdate(
        'UPDATE supplies SET quantity = quantity + ? WHERE id = ?',
        [log.qty, log.supplyId],
      );
    });
  }

  /// 消耗：写流水 + 库存扣减（事务，库存不足时按剩余量扣）
  /// [petId] 可选：本次消耗关联的宠物
  Future<void> consumeSupply(String supplyId, double qty,
      {String? recordId, String? date, String? note, String? petId}) async {
    final d = await database;
    await d.transaction((txn) async {
      final rows = await txn.query('supplies', where: 'id=?', whereArgs: [supplyId]);
      if (rows.isEmpty) return;
      final stock = (rows.first['quantity'] as num?)?.toDouble() ?? 0;
      final used = qty > stock ? stock : qty;
      if (used <= 0) return;
      await txn.insert('supply_logs', SupplyLog(
        id: genId(),
        supplyId: supplyId,
        type: 'out',
        qty: used,
        date: date ?? DateTime.now().toIso8601String().substring(0, 10),
        note: note,
        recordId: recordId,
        petId: petId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ).toMap());
      await txn.rawUpdate(
        'UPDATE supplies SET quantity = quantity - ? WHERE id = ?',
        [used, supplyId],
      );
    });
  }

  Future<List<SupplyLog>> getSupplyLogs(String supplyId) async {
    final d = await database;
    final rows = await d.query('supply_logs',
        where: 'supplyId=?', whereArgs: [supplyId], orderBy: 'date DESC, createdAt DESC');
    return rows.map(SupplyLog.fromMap).toList();
  }
  Future<List<SupplyLog>> getAllSupplyLogs() async {
    final d = await database;
    final rows = await d.query('supply_logs', orderBy: 'date DESC, createdAt DESC');
    return rows.map(SupplyLog.fromMap).toList();
  }

  /// 某宠物关联的全部用品流水（入库/消耗时选择的宠物），用于身价与消费统计
  Future<List<SupplyLog>> getSupplyLogsForPet(String petId) async {
    final d = await database;
    final rows = await d.query('supply_logs',
        where: 'petId=?', whereArgs: [petId], orderBy: 'date DESC, createdAt DESC');
    return rows.map(SupplyLog.fromMap).toList();
  }

  // ScoringRules（健康评分规则）
  Future<int> insertScoringRule(ScoringRule r) =>
      database.then((d) => d.insert('scoring_rules', r.toMap()));
  Future<List<ScoringRule>> getScoringRules() async {
    final d = await database;
    final rows = await d.query('scoring_rules', orderBy: 'createdAt ASC');
    return rows.map(ScoringRule.fromMap).toList();
  }
  Future<int> updateScoringRule(ScoringRule r) =>
      database.then((d) => d.update('scoring_rules', r.toMap(), where: 'id=?', whereArgs: [r.id]));
  Future<int> deleteScoringRule(String id) =>
      database.then((d) => d.delete('scoring_rules', where: 'id=?', whereArgs: [id]));
  Future<List<ScoringRule>> getAllScoringRules() => getScoringRules();

  // Records
  Future<int> insertRecord(HealthRecord r) =>
      database.then((d) => d.insert('records', r.toMap()));
  Future<List<HealthRecord>> getRecords(String petId, {String? type}) async {
    final d = await database;
    final where = type == null ? 'petId=?' : 'petId=? AND type=?';
    final args = type == null ? [petId] : [petId, type];
    final rows = await d.query('records', where: where, whereArgs: args, orderBy: 'recordDate DESC, createdAt DESC');
    return rows.map(HealthRecord.fromMap).toList();
  }
  Future<List<HealthRecord>> getAllRecords() async {
    final d = await database;
    final rows = await d.query('records', orderBy: 'recordDate DESC');
    return rows.map(HealthRecord.fromMap).toList();
  }
  Future<int> updateRecord(HealthRecord r) =>
      database.then((d) => d.update('records', r.toMap(), where: 'id=?', whereArgs: [r.id]));
  Future<int> deleteRecord(String id) =>
      database.then((d) => d.delete('records', where: 'id=?', whereArgs: [id]));

  // Reminders
  Future<int> insertReminder(Reminder r) =>
      database.then((d) => d.insert('reminders', r.toMap()));
  Future<List<Reminder>> getReminders(String petId) async {
    final d = await database;
    final rows = await d.query('reminders', where: 'petId=?', whereArgs: [petId], orderBy: 'dueDate ASC');
    return rows.map(Reminder.fromMap).toList();
  }
  Future<List<Reminder>> getAllReminders() async {
    final d = await database;
    final rows = await d.query('reminders');
    return rows.map(Reminder.fromMap).toList();
  }
  Future<void> importData(Map<String, dynamic> data) async {
    final d = await database;
    await d.delete('records');
    await d.delete('reminders');
    await d.delete('album');
    await d.delete('pets');
    for (final p in (data['pets'] as List)) {
      await d.insert('pets', Pet.fromMap(p).toMap());
    }
    for (final r in (data['records'] as List)) {
      await d.insert('records', HealthRecord.fromMap(r).toMap());
    }
    for (final r in (data['reminders'] as List)) {
      await d.insert('reminders', Reminder.fromMap(r).toMap());
    }
      for (final a in (data['album'] as List? ?? [])) {
        await d.insert('album', AlbumEntry.fromMap(a).toMap());
      }
      for (final eq in (data['equipments'] as List? ?? [])) {
        await d.insert('equipments', Equipment.fromMap(eq).toMap());
      }
      for (final s in (data['supplies'] as List? ?? [])) {
        await d.insert('supplies', Supply.fromMap(s).toMap());
      }
      for (final l in (data['supplyLogs'] as List? ?? [])) {
        await d.insert('supply_logs', SupplyLog.fromMap(l).toMap());
      }
      for (final r in (data['scoringRules'] as List? ?? [])) {
        await d.insert('scoring_rules', ScoringRule.fromMap(r).toMap());
      }
  }
  Future<List<Reminder>> getDueReminders() async {
    final d = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await d.query('reminders', where: 'done=0 AND dueDate<=?', whereArgs: [today], orderBy: 'dueDate ASC');
    return rows.map(Reminder.fromMap).toList();
  }

  // Album
  Future<int> insertAlbumEntry(AlbumEntry e) =>
      database.then((d) => d.insert('album', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace));
  Future<int> updateAlbumEntry(AlbumEntry e) =>
      database.then((d) => d.update('album', e.toMap(), where: 'id=?', whereArgs: [e.id]));
  Future<List<AlbumEntry>> getAlbumEntries(String petId) async {
    final d = await database;
    final rows = await d.query('album', where: 'petId=?', whereArgs: [petId], orderBy: 'date DESC');
    return rows.map(AlbumEntry.fromMap).toList();
  }
  Future<AlbumEntry?> getAlbumEntryByDate(String petId, String date) async {
    final d = await database;
    final rows = await d.query('album', where: 'petId=? AND date=?', whereArgs: [petId, date]);
    if (rows.isEmpty) return null;
    return AlbumEntry.fromMap(rows.first);
  }
  Future<int> deleteAlbumEntry(String id) =>
      database.then((d) => d.delete('album', where: 'id=?', whereArgs: [id]));

  // 导出全部数据为 Map（供 WebDAV 同步使用）
  Future<Map<String, dynamic>> exportPayload() async {
    final pets = await getPets();
    final recs = await getAllRecords();
    final rems = await getAllReminders();
    final albumRows = await getAllAlbumEntries();
    final eqRows = await getAllEquipments();
    final supRows = await getSupplies();
    final supLogRows = await getAllSupplyLogs();
    final ruleRows = await getScoringRules();
    return {
      'app': 'pet_health_app',
      'version': 5,
      'exportedAt': DateTime.now().toIso8601String(),
      'pets': pets.map((e) => e.toMap()).toList(),
      'records': recs.map((e) => e.toMap()).toList(),
      'reminders': rems.map((e) => e.toMap()).toList(),
      'album': albumRows.map((e) => e.toMap()).toList(),
      'equipments': eqRows.map((e) => e.toMap()).toList(),
      'supplies': supRows.map((e) => e.toMap()).toList(),
      'supplyLogs': supLogRows.map((e) => e.toMap()).toList(),
      'scoringRules': ruleRows.map((e) => e.toMap()).toList(),
    };
  }

  Future<List<Equipment>> getAllEquipments() async {
    final d = await database;
    final rows = await d.query('equipments', orderBy: 'createdAt DESC');
    return rows.map(Equipment.fromMap).toList();
  }

  Future<List<AlbumEntry>> getAllAlbumEntries() async {
    final d = await database;
    final rows = await d.query('album', orderBy: 'date DESC');
    return rows.map(AlbumEntry.fromMap).toList();
  }

  // 合并远程数据：仅插入本地缺失的行（按 id），不覆盖本地已有数据，避免误删
  Future<int> mergeData(Map<String, dynamic> data) async {
    final d = await database;
    int added = 0;
    for (final p in (data['pets'] as List? ?? [])) {
      final exist = await d.query('pets', where: 'id=?', whereArgs: [p['id']]);
      if (exist.isEmpty) {
        await d.insert('pets', Pet.fromMap(p).toMap());
        added++;
      }
    }
    for (final r in (data['records'] as List? ?? [])) {
      final exist = await d.query('records', where: 'id=?', whereArgs: [r['id']]);
      if (exist.isEmpty) {
        await d.insert('records', HealthRecord.fromMap(r).toMap());
        added++;
      }
    }
    for (final r in (data['reminders'] as List? ?? [])) {
      final exist = await d.query('reminders', where: 'id=?', whereArgs: [r['id']]);
      if (exist.isEmpty) {
        await d.insert('reminders', Reminder.fromMap(r).toMap());
        added++;
      }
    }
    for (final a in (data['album'] as List? ?? [])) {
      final exist = await d.query('album', where: 'id=?', whereArgs: [a['id']]);
      if (exist.isEmpty) {
        await d.insert('album', AlbumEntry.fromMap(a).toMap());
        added++;
      }
    }
    for (final eq in (data['equipments'] as List? ?? [])) {
      final exist = await d.query('equipments', where: 'id=?', whereArgs: [eq['id']]);
      if (exist.isEmpty) {
        await d.insert('equipments', Equipment.fromMap(eq).toMap());
        added++;
      }
    }
    for (final s in (data['supplies'] as List? ?? [])) {
      final exist = await d.query('supplies', where: 'id=?', whereArgs: [s['id']]);
      if (exist.isEmpty) {
        await d.insert('supplies', Supply.fromMap(s).toMap());
        added++;
      }
    }
    for (final l in (data['supplyLogs'] as List? ?? [])) {
      final exist = await d.query('supply_logs', where: 'id=?', whereArgs: [l['id']]);
      if (exist.isEmpty) {
        await d.insert('supply_logs', SupplyLog.fromMap(l).toMap());
        added++;
      }
    }
    for (final r in (data['scoringRules'] as List? ?? [])) {
      final exist = await d.query('scoring_rules', where: 'id=?', whereArgs: [r['id']]);
      if (exist.isEmpty) {
        await d.insert('scoring_rules', ScoringRule.fromMap(r).toMap());
        added++;
      }
    }
    return added;
  }
  Future<int> updateReminder(Reminder r) =>
      database.then((d) => d.update('reminders', r.toMap(), where: 'id=?', whereArgs: [r.id]));
  Future<int> deleteReminder(String id) =>
      database.then((d) => d.delete('reminders', where: 'id=?', whereArgs: [id]));

  // Settings
  Future<AppSettings?> getSettings() async {
    final d = await database;
    final rows = await d.query('settings', where: 'id=?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return AppSettings.fromMap(rows.first);
  }
  Future<int> saveSettings(AppSettings s) =>
      database.then((d) => d.insert('settings', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace));
}
