import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moment/models/moment_record.dart';
import 'package:moment/services/database_service.dart';
import 'package:moment/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService databaseService;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseService = DatabaseService();
    await databaseService.close();

    SharedPreferences.setMockInitialValues({});
    await StorageService().init();

    databasePath = join(await getDatabasesPath(), 'moment.db');
    await deleteDatabase(databasePath);
  });

  tearDown(() async {
    await databaseService.close();
    await deleteDatabase(databasePath);
  });

  test('records are isolated by user id', () async {
    final userARecord = MomentRecord(
      id: 'moment-a',
      content: 'A user moment',
      createdAt: DateTime.parse('2026-04-20T10:00:00'),
      mediaType: MediaType.text,
      mediaPaths: const [],
    );
    final userBRecord = MomentRecord(
      id: 'moment-b',
      content: 'B user moment',
      createdAt: DateTime.parse('2026-04-20T11:00:00'),
      mediaType: MediaType.image,
      mediaPaths: const ['/tmp/image.jpg'],
    );

    await databaseService.insertMoment(userARecord, userId: 'user-a');
    await databaseService.insertMoment(userBRecord, userId: 'user-b');

    final userAMoments = await databaseService.getAllMoments(userId: 'user-a');
    final userBMoments = await databaseService.getAllMoments(userId: 'user-b');

    expect(userAMoments, hasLength(1));
    expect(userAMoments.single.id, 'moment-a');
    expect(userBMoments, hasLength(1));
    expect(userBMoments.single.id, 'moment-b');
    expect(
      await databaseService.getMoment('moment-b', userId: 'user-a'),
      isNull,
    );
  });

  test('version 1 database is migrated and backfilled with current user id',
      () async {
    SharedPreferences.setMockInitialValues({
      'user_id': 'legacy-user',
    });
    await StorageService().init();

    final legacyDb = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE moments (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            media_type INTEGER NOT NULL,
            media_paths TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    await legacyDb.insert('moments', {
      'id': 'legacy-moment',
      'content': 'Legacy content',
      'created_at': '2026-04-19T08:30:00.000',
      'updated_at': null,
      'media_type': MediaType.text.index,
      'media_paths': '',
      'synced': 0,
    });
    await legacyDb.close();

    final migratedMoments =
        await databaseService.getAllMoments(userId: 'legacy-user');
    expect(migratedMoments, hasLength(1));
    expect(migratedMoments.single.id, 'legacy-moment');
    expect(migratedMoments.single.content, 'Legacy content');

    final db = await databaseService.database;
    final columns = await db.rawQuery('PRAGMA table_info(moments)');
    final columnNames = columns.map((column) => column['name']).toSet();
    expect(columnNames, contains('user_id'));
    expect(columnNames, contains('server_id'));
    expect(columnNames, contains('sync_status'));
    expect(columnNames, contains('last_synced_at'));
    expect(columnNames, contains('conflict_remote_updated_at'));

    final migratedRows = await db.query(
      'moments',
      columns: [
        'user_id',
        'server_id',
        'sync_status',
        'last_synced_at',
        'conflict_remote_updated_at',
      ],
      where: 'id = ?',
      whereArgs: ['legacy-moment'],
    );
    expect(migratedRows.single['user_id'], 'legacy-user');
    expect(migratedRows.single['server_id'], isNull);
    expect(migratedRows.single['sync_status'], SyncStatus.localOnly.index);
    expect(migratedRows.single['last_synced_at'], isNull);
    expect(migratedRows.single['conflict_remote_updated_at'], isNull);
  });

  test('version 2 synced numeric ids are migrated to explicit server ids',
      () async {
    final legacyDb = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE moments (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            media_type INTEGER NOT NULL,
            media_paths TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_moments_user_id_created_at ON moments(user_id, created_at DESC)',
        );
      },
    );

    await legacyDb.insert('moments', {
      'id': '42',
      'user_id': 'user-a',
      'content': 'Server-backed legacy content',
      'created_at': '2026-04-18T08:30:00.000',
      'updated_at': '2026-04-19T09:30:00.000',
      'media_type': MediaType.text.index,
      'media_paths': '',
      'synced': 1,
    });
    await legacyDb.close();

    final migratedMoments =
        await databaseService.getAllMoments(userId: 'user-a');
    expect(migratedMoments, hasLength(1));
    expect(migratedMoments.single.id, '42');
    expect(migratedMoments.single.serverId, '42');
    expect(migratedMoments.single.syncStatus, SyncStatus.synced);
    expect(migratedMoments.single.lastSyncedAt, isNotNull);
  });

  test(
      'conflict records are excluded from upload queue until explicitly promoted',
      () async {
    final conflictRecord = MomentRecord(
      id: 'moment-conflict',
      serverId: '100',
      content: 'Local edit',
      createdAt: DateTime.parse('2026-04-20T12:00:00'),
      updatedAt: DateTime.parse('2026-04-21T09:00:00'),
      mediaType: MediaType.text,
      mediaPaths: const [],
      synced: false,
      syncStatus: SyncStatus.conflict,
      lastSyncedAt: DateTime.parse('2026-04-20T08:00:00'),
    );

    await databaseService.insertMoment(conflictRecord, userId: 'user-a');

    final pendingBefore =
        await databaseService.getUnsyncedMoments(userId: 'user-a');
    final conflictsBefore =
        await databaseService.getConflictMoments(userId: 'user-a');
    expect(pendingBefore, isEmpty);
    expect(conflictsBefore, hasLength(1));
    expect(conflictsBefore.single.syncStatus, SyncStatus.conflict);

    final promoted = await databaseService.promoteConflictMomentsForUpload(
      userId: 'user-a',
    );
    expect(promoted, 1);

    final pendingAfter =
        await databaseService.getUnsyncedMoments(userId: 'user-a');
    final conflictsAfter =
        await databaseService.getConflictMoments(userId: 'user-a');
    expect(pendingAfter, hasLength(1));
    expect(pendingAfter.single.syncStatus, SyncStatus.pendingUpload);
    expect(conflictsAfter, isEmpty);
  });

  test('single conflict record can be promoted without affecting others',
      () async {
    final first = MomentRecord(
      id: 'moment-conflict-1',
      serverId: '101',
      content: 'Local edit A',
      createdAt: DateTime.parse('2026-04-20T12:00:00'),
      mediaType: MediaType.text,
      mediaPaths: const [],
      synced: false,
      syncStatus: SyncStatus.conflict,
    );
    final second = MomentRecord(
      id: 'moment-conflict-2',
      serverId: '102',
      content: 'Local edit B',
      createdAt: DateTime.parse('2026-04-20T13:00:00'),
      mediaType: MediaType.text,
      mediaPaths: const [],
      synced: false,
      syncStatus: SyncStatus.conflict,
    );

    await databaseService.insertMoment(first, userId: 'user-a');
    await databaseService.insertMoment(second, userId: 'user-a');

    final changed = await databaseService.promoteConflictMomentForUpload(
      'moment-conflict-1',
      userId: 'user-a',
    );
    expect(changed, 1);

    final firstAfter = await databaseService.getMoment(
      'moment-conflict-1',
      userId: 'user-a',
    );
    final secondAfter = await databaseService.getMoment(
      'moment-conflict-2',
      userId: 'user-a',
    );
    expect(firstAfter?.syncStatus, SyncStatus.pendingUpload);
    expect(firstAfter?.conflictRemoteUpdatedAt, isNull);
    expect(secondAfter?.syncStatus, SyncStatus.conflict);
  });

  test('version 3 database is migrated with remote conflict timestamp column',
      () async {
    final legacyDb = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, version) async {
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
            last_synced_at TEXT
          )
        ''');
      },
    );
    await legacyDb.close();

    final db = await databaseService.database;
    final columns = await db.rawQuery('PRAGMA table_info(moments)');
    final columnNames = columns.map((column) => column['name']).toSet();
    expect(columnNames, contains('conflict_remote_updated_at'));
  });
}
