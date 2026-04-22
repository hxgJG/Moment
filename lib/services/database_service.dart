import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/moment_record.dart';
import 'storage_service.dart';
import '../utils/media_source.dart';

/// 数据库服务 - 管理本地SQLite数据库
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  final StorageService _storage = StorageService();

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
    final path = join(await getDatabasesPath(), 'moment.db');
    final currentUserId = await _storage.getUserId();
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _onUpgrade(db, oldVersion, newVersion, currentUserId);
      },
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE moments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        server_id TEXT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        media_type INTEGER NOT NULL,
        media_paths TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        sync_status INTEGER NOT NULL DEFAULT 0,
        last_synced_at TEXT,
        conflict_remote_updated_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_moments_user_id_created_at ON moments(user_id, created_at DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_moments_user_id_server_id ON moments(user_id, server_id)',
    );
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
    String? currentUserId,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE moments ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_moments_user_id_created_at ON moments(user_id, created_at DESC)',
      );
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await db.update(
          'moments',
          {'user_id': currentUserId},
          where: "user_id = ''",
        );
      }
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE moments ADD COLUMN server_id TEXT');
      await db.execute(
        'ALTER TABLE moments ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE moments ADD COLUMN last_synced_at TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_moments_user_id_server_id ON moments(user_id, server_id)',
      );
      await db.execute('''
        UPDATE moments
        SET
          server_id = CASE
            WHEN synced = 1 AND id GLOB '[0-9]*' THEN id
            ELSE NULL
          END,
          sync_status = CASE
            WHEN synced = 1 THEN ${SyncStatus.synced.index}
            WHEN id GLOB '[0-9]*' THEN ${SyncStatus.pendingUpload.index}
            ELSE ${SyncStatus.localOnly.index}
          END,
          last_synced_at = CASE
            WHEN synced = 1 THEN COALESCE(updated_at, created_at)
            ELSE NULL
          END
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE moments ADD COLUMN conflict_remote_updated_at TEXT',
      );
    }
  }

  /// 插入记录
  Future<void> insertMoment(
    MomentRecord record, {
    required String userId,
  }) async {
    final db = await database;
    final map = record.toMap();
    map['user_id'] = userId;
    await db.insert(
      'moments',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除记录
  Future<void> deleteMoment(String id, {required String userId}) async {
    final db = await database;
    await db.delete(
      'moments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// 更新记录
  Future<void> updateMoment(
    MomentRecord record, {
    required String userId,
  }) async {
    final db = await database;
    await db.update(
      'moments',
      {
        ...record.toMap(),
        'user_id': userId,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [record.id, userId],
    );
  }

  /// 获取所有记录（按时间倒序）
  Future<List<MomentRecord>> getAllMoments({required String userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MomentRecord.fromMap(maps[i]));
  }

  /// 获取单条记录
  Future<MomentRecord?> getMoment(String id, {required String userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (maps.isEmpty) return null;
    return MomentRecord.fromMap(maps.first);
  }

  /// 获取记录统计
  Future<Map<String, int>> getStatistics({required String userId}) async {
    final db = await database;
    final total = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ?',
            [userId],
          ),
        ) ??
        0;

    // 按媒体类型统计
    final imageCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ? AND media_type = ?',
            [userId, MediaType.image.index],
          ),
        ) ??
        0;

    final audioCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ? AND media_type = ?',
            [userId, MediaType.audio.index],
          ),
        ) ??
        0;

    final videoCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ? AND media_type = ?',
            [userId, MediaType.video.index],
          ),
        ) ??
        0;

    final textCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ? AND media_type = ?',
            [userId, MediaType.text.index],
          ),
        ) ??
        0;

    final mixedCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM moments WHERE user_id = ? AND media_type = ?',
            [userId, MediaType.mixed.index],
          ),
        ) ??
        0;

    return {
      'total': total,
      'image': imageCount,
      'audio': audioCount,
      'video': videoCount,
      'text': textCount,
      'mixed': mixedCount,
    };
  }

  /// 获取未同步的记录
  Future<List<MomentRecord>> getUnsyncedMoments(
      {required String userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      where: 'user_id = ? AND sync_status IN (?, ?)',
      whereArgs: [
        userId,
        SyncStatus.localOnly.index,
        SyncStatus.pendingUpload.index,
      ],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MomentRecord.fromMap(maps[i]));
  }

  /// 获取冲突中的记录
  Future<List<MomentRecord>> getConflictMoments(
      {required String userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'moments',
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, SyncStatus.conflict.index],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MomentRecord.fromMap(maps[i]));
  }

  /// 保存同步后的记录状态
  Future<void> saveSyncedMoment(
    MomentRecord record, {
    required String userId,
  }) async {
    final db = await database;
    final map = record.toMap();
    map['user_id'] = userId;
    await db.insert(
      'moments',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 将所有记录重新加入同步队列（用于修复历史状态或重试同步）
  Future<int> resetAllMomentsSyncFlags({required String userId}) async {
    final db = await database;
    return db.rawUpdate(
      '''
      UPDATE moments
      SET
        synced = 0,
        sync_status = CASE
          WHEN server_id IS NULL OR server_id = '' THEN ?
          ELSE ?
        END,
        last_synced_at = NULL
      WHERE user_id = ?
      ''',
      [
        SyncStatus.localOnly.index,
        SyncStatus.pendingUpload.index,
        userId,
      ],
    );
  }

  /// 将冲突记录重新标记为待上传，表示用户确认以本地为准覆盖云端
  Future<int> promoteConflictMomentsForUpload({required String userId}) async {
    final db = await database;
    return db.update(
      'moments',
      {
        'synced': 0,
        'sync_status': SyncStatus.pendingUpload.index,
        'conflict_remote_updated_at': null,
      },
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, SyncStatus.conflict.index],
    );
  }

  /// 将单条冲突记录重新标记为待上传
  Future<int> promoteConflictMomentForUpload(
    String id, {
    required String userId,
  }) async {
    final db = await database;
    return db.update(
      'moments',
      {
        'synced': 0,
        'sync_status': SyncStatus.pendingUpload.index,
        'conflict_remote_updated_at': null,
      },
      where: 'id = ? AND user_id = ? AND sync_status = ?',
      whereArgs: [id, userId, SyncStatus.conflict.index],
    );
  }

  Future<MomentRecord?> getMomentByServerId(
    String serverId, {
    required String userId,
  }) async {
    final db = await database;
    final maps = await db.query(
      'moments',
      where: 'user_id = ? AND server_id = ?',
      whereArgs: [userId, serverId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MomentRecord.fromMap(maps.first);
  }

  Future<void> upsertMomentByServerId(
    String serverId,
    MomentRecord serverRecord, {
    required String userId,
  }) async {
    final existing = await getMomentByServerId(serverId, userId: userId);
    final nextRecord = serverRecord.copyWith(
      id: existing?.id ?? serverRecord.id,
      serverId: serverId,
    );
    await saveSyncedMoment(nextRecord, userId: userId);
  }

  /// 保留本地主键并回填服务端标识
  Future<void> attachServerIdentity(
    String localId,
    MomentRecord serverRecord, {
    required String userId,
  }) async {
    final db = await database;
    await db.update(
      'moments',
      {
        ...serverRecord.toMap(),
        'id': localId,
        'user_id': userId,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [localId, userId],
    );
  }

  Future<List<String>> getAllLocalMediaPaths() async {
    final db = await database;
    final rows = await db.query(
      'moments',
      columns: ['media_paths'],
    );

    final result = <String>[];
    for (final row in rows) {
      final raw = row['media_paths']?.toString() ?? '';
      if (raw.isEmpty) {
        continue;
      }
      for (final path in raw.split(',')) {
        if (path.isNotEmpty && isLocalMediaPath(path)) {
          result.add(path);
        }
      }
    }
    return result;
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    await db.close();
    _database = null;
  }
}
