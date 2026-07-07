import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/entries.dart';

/// Stockage local SQLite. L'app fonctionne 100 % offline ;
/// la colonne `synced` permet la synchro différée vers l'API REST.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      join(dir, 'bibitrack.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE feedings(
            id TEXT PRIMARY KEY,
            at INTEGER NOT NULL,
            amount_ml INTEGER,
            side TEXT,
            vitamin_d INTEGER NOT NULL DEFAULT 0,
            next_at INTEGER,
            synced INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE diapers(
            id TEXT PRIMARY KEY,
            at INTEGER NOT NULL,
            type TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE sleeps(
            id TEXT PRIMARY KEY,
            start INTEGER NOT NULL,
            end INTEGER,
            synced INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute(_createBathsTable);
        await db.execute('CREATE INDEX idx_feedings_at ON feedings(at DESC)');
        await db.execute('CREATE INDEX idx_diapers_at ON diapers(at DESC)');
        await db.execute('CREATE INDEX idx_sleeps_start ON sleeps(start DESC)');
        await db.execute(_createBathsIndex);
      },
      // Migration des installations existantes (base déjà en v1).
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createBathsTable);
          await db.execute(_createBathsIndex);
        }
      },
    );
  }

  static const _createBathsTable = '''
    CREATE TABLE baths(
      id TEXT PRIMARY KEY,
      at INTEGER NOT NULL,
      type TEXT NOT NULL,
      notes TEXT,
      synced INTEGER NOT NULL DEFAULT 0
    )''';

  static const _createBathsIndex =
      'CREATE INDEX idx_baths_at ON baths(at DESC)';

  // ---------- Feedings ----------
  Future<void> insertFeeding(FeedingEntry e) async =>
      (await db).insert('feedings', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<FeedingEntry>> feedings({int limit = 200}) async {
    final rows = await (await db)
        .query('feedings', orderBy: 'at DESC', limit: limit);
    return rows.map(FeedingEntry.fromMap).toList();
  }

  Future<FeedingEntry?> lastFeeding() async {
    final rows =
    await (await db).query('feedings', orderBy: 'at DESC', limit: 1);
    return rows.isEmpty ? null : FeedingEntry.fromMap(rows.first);
  }

  Future<void> deleteFeeding(String id) async =>
      (await db).delete('feedings', where: 'id = ?', whereArgs: [id]);

  // ---------- Diapers ----------
  Future<void> insertDiaper(DiaperEntry e) async =>
      (await db).insert('diapers', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<DiaperEntry>> diapers({int limit = 200}) async {
    final rows =
    await (await db).query('diapers', orderBy: 'at DESC', limit: limit);
    return rows.map(DiaperEntry.fromMap).toList();
  }

  Future<void> deleteDiaper(String id) async =>
      (await db).delete('diapers', where: 'id = ?', whereArgs: [id]);

  // ---------- Sleeps ----------
  Future<void> upsertSleep(SleepEntry e) async =>
      (await db).insert('sleeps', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<SleepEntry>> sleeps({int limit = 200}) async {
    final rows =
    await (await db).query('sleeps', orderBy: 'start DESC', limit: limit);
    return rows.map(SleepEntry.fromMap).toList();
  }

  /// Sommeil en cours (end IS NULL), s'il existe.
  Future<SleepEntry?> ongoingSleep() async {
    final rows = await (await db).query('sleeps',
        where: 'end IS NULL', orderBy: 'start DESC', limit: 1);
    return rows.isEmpty ? null : SleepEntry.fromMap(rows.first);
  }

  Future<void> deleteSleep(String id) async =>
      (await db).delete('sleeps', where: 'id = ?', whereArgs: [id]);

  // ---------- Baths ----------
  Future<void> insertBath(BathEntry e) async =>
      (await db).insert('baths', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<BathEntry>> baths({int limit = 200}) async {
    final rows =
    await (await db).query('baths', orderBy: 'at DESC', limit: limit);
    return rows.map(BathEntry.fromMap).toList();
  }

  Future<BathEntry?> lastBath() async {
    final rows =
    await (await db).query('baths', orderBy: 'at DESC', limit: 1);
    return rows.isEmpty ? null : BathEntry.fromMap(rows.first);
  }

  Future<void> deleteBath(String id) async =>
      (await db).delete('baths', where: 'id = ?', whereArgs: [id]);

  // ---------- Sync ----------
  Future<Map<String, List<Map<String, dynamic>>>> unsyncedPayload() async {
    final d = await db;
    final f = await d.query('feedings', where: 'synced = 0');
    final di = await d.query('diapers', where: 'synced = 0');
    final s = await d.query('sleeps', where: 'synced = 0');
    final b = await d.query('baths', where: 'synced = 0');
    return {
      'feedings': f.map((m) => FeedingEntry.fromMap(m).toJson()).toList(),
      'diapers': di.map((m) => DiaperEntry.fromMap(m).toJson()).toList(),
      'sleeps': s.map((m) => SleepEntry.fromMap(m).toJson()).toList(),
      'baths': b.map((m) => BathEntry.fromMap(m).toJson()).toList(),
    };
  }

  Future<void> markAllSynced() async {
    final d = await db;
    await d.update('feedings', {'synced': 1});
    await d.update('diapers', {'synced': 1});
    await d.update('sleeps', {'synced': 1});
    await d.update('baths', {'synced': 1});
  }
}