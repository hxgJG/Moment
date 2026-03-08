import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/moment_record.dart';

/// 数据库服务 - 管理本地SQLite数据库
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'moment.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE moments (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        media_type INTEGER NOT NULL,
        media_paths TEXT NOT NULL
      )
    ''');
  }

  /// 插入记录
  Future<void> insertMoment(MomentRecord record) async {
    final db = await database;
    await db.insert(
      'moments',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除记录
  Future<void> deleteMoment(String id) async {
    final db = await database;
    await db.delete(
      'moments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新记录
  Future<void> updateMoment(MomentRecord record) async {
    final db = await database;
    await db.update(
      'moments',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 获取所有记录（按时间倒序）
  Future<List<MomentRecord>> getAllMoments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MomentRecord.fromMap(maps[i]));
  }

  /// 获取单条记录
  Future<MomentRecord?> getMoment(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MomentRecord.fromMap(maps.first);
  }

  /// 获取记录统计
  Future<Map<String, int>> getStatistics() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments'),
    ) ?? 0;

    // 按媒体类型统计
    final imageCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments WHERE media_type = ?', [MediaType.image.index]),
    ) ?? 0;

    final audioCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments WHERE media_type = ?', [MediaType.audio.index]),
    ) ?? 0;

    final videoCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments WHERE media_type = ?', [MediaType.video.index]),
    ) ?? 0;

    final textCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments WHERE media_type = ?', [MediaType.text.index]),
    ) ?? 0;

    final mixedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moments WHERE media_type = ?', [MediaType.mixed.index]),
    ) ?? 0;

    return {
      'total': total,
      'image': imageCount,
      'audio': audioCount,
      'video': videoCount,
      'text': textCount,
      'mixed': mixedCount,
    };
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
