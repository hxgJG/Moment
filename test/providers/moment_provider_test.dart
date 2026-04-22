import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moment/models/moment_record.dart';
import 'package:moment/providers/moment_provider.dart';

void main() {
  group('MomentProvider syncToServer', () {
    test('local-only records are created with client_id and synced back',
        () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      await db.insertMoment(
        MomentRecord(
          id: 'local-1',
          content: 'hello',
          createdAt: DateTime.parse('2026-04-21T10:00:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: false,
          syncStatus: SyncStatus.localOnly,
        ),
        userId: 'user-a',
      );

      api.onPost = ({
        required String path,
        dynamic data,
      }) async {
        expect(path, '/moments');
        expect(data, isA<Map<String, dynamic>>());
        final body = data as Map<String, dynamic>;
        expect(body['client_id'], 'local-1');
        expect(body['media_type'], 'text');
        expect(body['media_paths'], isEmpty);
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'id': 901,
              'content': 'hello',
              'media_type': 'text',
              'media_paths': <String>[],
              'created_at': '2026-04-21 10:00:00',
              'updated_at': '2026-04-21 10:00:00',
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.syncToServer();

      expect(result, isTrue);
      expect(provider.lastSyncUploaded, 1);
      expect(provider.lastSyncFailed, 0);
      final saved = await db.getMoment('local-1', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.serverId, '901');
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.lastSyncedAt, isNotNull);
    });

    test('server-backed pending records are updated without client_id',
        () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      await db.insertMoment(
        MomentRecord(
          id: 'local-2',
          serverId: '123',
          content: 'updated content',
          createdAt: DateTime.parse('2026-04-20T10:00:00'),
          updatedAt: DateTime.parse('2026-04-21T09:30:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: false,
          syncStatus: SyncStatus.pendingUpload,
          lastSyncedAt: DateTime.parse('2026-04-20T10:05:00'),
        ),
        userId: 'user-a',
      );

      api.onPut = ({
        required String path,
        dynamic data,
      }) async {
        expect(path, '/moments/123');
        expect(data, isA<Map<String, dynamic>>());
        final body = data as Map<String, dynamic>;
        expect(body.containsKey('client_id'), isFalse);
        expect(body['content'], 'updated content');
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': null,
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.syncToServer();

      expect(result, isTrue);
      expect(provider.lastSyncUploaded, 1);
      expect(provider.lastSyncFailed, 0);
      final saved = await db.getMoment('local-2', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.serverId, '123');
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.lastSyncedAt, isNotNull);
    });
  });

  group('MomentProvider fetchFromServer', () {
    test('remote-only records are inserted into local store', () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        expect(path, '/moments');
        expect(queryParameters?['page'], 1);
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'list': [
                {
                  'id': 777,
                  'content': 'remote only',
                  'media_type': 'text',
                  'media_paths': <String>[],
                  'created_at': '2026-04-21 08:00:00',
                  'updated_at': '2026-04-21 08:00:00',
                },
              ],
              'total_pages': 1,
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.fetchFromServer();

      expect(result, isTrue);
      final saved = await db.getMoment('remote_777', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.serverId, '777');
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.content, 'remote only');
    });

    test('synced local records are refreshed from newer remote data', () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      await db.insertMoment(
        MomentRecord(
          id: 'local-synced-1',
          serverId: '501',
          content: 'old content',
          createdAt: DateTime.parse('2026-04-20T08:00:00'),
          updatedAt: DateTime.parse('2026-04-20T09:00:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: true,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.parse('2026-04-20T09:00:00'),
        ),
        userId: 'user-a',
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'list': [
                {
                  'id': 501,
                  'content': 'remote latest',
                  'media_type': 'text',
                  'media_paths': <String>[],
                  'created_at': '2026-04-20 08:00:00',
                  'updated_at': '2026-04-21 10:00:00',
                },
              ],
              'total_pages': 1,
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.fetchFromServer();

      expect(result, isTrue);
      final saved = await db.getMoment('local-synced-1', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.content, 'remote latest');
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.lastSyncedAt, isNotNull);
    });

    test('pending local edits become conflict when remote changed later',
        () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      await db.insertMoment(
        MomentRecord(
          id: 'local-pending-1',
          serverId: '601',
          content: 'local edited',
          createdAt: DateTime.parse('2026-04-20T08:00:00'),
          updatedAt: DateTime.parse('2026-04-21T09:30:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: false,
          syncStatus: SyncStatus.pendingUpload,
          lastSyncedAt: DateTime.parse('2026-04-20T10:00:00'),
        ),
        userId: 'user-a',
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'list': [
                {
                  'id': 601,
                  'content': 'remote edited later',
                  'media_type': 'text',
                  'media_paths': <String>[],
                  'created_at': '2026-04-20 08:00:00',
                  'updated_at': '2026-04-21 10:30:00',
                },
              ],
              'total_pages': 1,
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.fetchFromServer();

      expect(result, isTrue);
      final saved = await db.getMoment('local-pending-1', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.content, 'local edited');
      expect(saved.syncStatus, SyncStatus.conflict);
      expect(
        saved.conflictRemoteUpdatedAt,
        DateTime.parse('2026-04-21T10:30:00'),
      );
    });

    test('synced local records deleted remotely are removed locally', () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'moment-provider-remote-delete',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final localFile = File('${tempDir.path}/synced.jpg');
      await localFile.writeAsString('synced-media');

      await db.insertMoment(
        MomentRecord(
          id: 'local-synced-deleted',
          serverId: '999',
          content: 'to be removed',
          createdAt: DateTime.parse('2026-04-20T08:00:00'),
          updatedAt: DateTime.parse('2026-04-20T09:00:00'),
          mediaType: MediaType.image,
          mediaPaths: [localFile.path],
          synced: true,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.parse('2026-04-20T09:00:00'),
        ),
        userId: 'user-a',
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        expect(path, '/moments');
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'list': <dynamic>[],
              'total_pages': 1,
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.fetchFromServer();

      expect(result, isTrue);
      expect(
        await db.getMoment('local-synced-deleted', userId: 'user-a'),
        isNull,
      );
      expect(await localFile.exists(), isFalse);
    });
  });

  group('MomentProvider conflict resolution', () {
    test(
        'single conflict can be replaced by remote version and delete local media',
        () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'moment-provider-conflict-single',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final localFile = File('${tempDir.path}/local.jpg');
      await localFile.writeAsString('local-media');

      await db.insertMoment(
        MomentRecord(
          id: 'local-conflict-1',
          serverId: '701',
          content: 'local conflict',
          createdAt: DateTime.parse('2026-04-20T08:00:00'),
          updatedAt: DateTime.parse('2026-04-21T09:00:00'),
          mediaType: MediaType.image,
          mediaPaths: [localFile.path],
          synced: false,
          syncStatus: SyncStatus.conflict,
          lastSyncedAt: DateTime.parse('2026-04-20T10:00:00'),
          conflictRemoteUpdatedAt: DateTime.parse('2026-04-21T10:30:00'),
        ),
        userId: 'user-a',
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        expect(path, '/moments/701');
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'id': 701,
              'content': 'remote resolved',
              'media_type': 'image',
              'media_paths': ['https://cdn.example.com/remote.jpg'],
              'created_at': '2026-04-20 08:00:00',
              'updated_at': '2026-04-21 10:30:00',
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final result = await provider.resolveConflictMomentWithRemote(
        'local-conflict-1',
      );

      expect(result, isTrue);
      expect(await localFile.exists(), isFalse);

      final saved = await db.getMoment('local-conflict-1', userId: 'user-a');
      expect(saved, isNotNull);
      expect(saved!.content, 'remote resolved');
      expect(saved.mediaPaths, ['https://cdn.example.com/remote.jpg']);
      expect(saved.syncStatus, SyncStatus.synced);
      expect(saved.conflictRemoteUpdatedAt, isNull);
    });

    test('batch conflict resolution only applies when remote version exists',
        () async {
      final db = _FakeMomentDatabase();
      final api = _FakeMomentApiClient();
      final provider = MomentProvider(
        dbService: db,
        api: api,
        autoFetchOnBind: false,
      );

      await db.insertMoment(
        MomentRecord(
          id: 'local-conflict-2',
          serverId: '801',
          content: 'local conflict A',
          createdAt: DateTime.parse('2026-04-20T08:00:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: false,
          syncStatus: SyncStatus.conflict,
        ),
        userId: 'user-a',
      );
      await db.insertMoment(
        MomentRecord(
          id: 'local-conflict-3',
          serverId: '802',
          content: 'local conflict B',
          createdAt: DateTime.parse('2026-04-20T09:00:00'),
          mediaType: MediaType.text,
          mediaPaths: const [],
          synced: false,
          syncStatus: SyncStatus.conflict,
        ),
        userId: 'user-a',
      );

      api.onGet = ({
        required String path,
        Map<String, dynamic>? queryParameters,
      }) async {
        expect(path, '/moments');
        return const ApiCallResult(
          statusCode: 200,
          data: {
            'code': 200,
            'msg': 'ok',
            'data': {
              'list': [
                {
                  'id': 801,
                  'content': 'remote resolved A',
                  'media_type': 'text',
                  'media_paths': <String>[],
                  'created_at': '2026-04-20 08:00:00',
                  'updated_at': '2026-04-21 11:00:00',
                },
              ],
              'total_pages': 1,
            },
          },
        );
      };

      await provider.bindUser('user-a');
      final resolved = await provider.resolveConflictMomentsWithRemote();

      expect(resolved, 1);
      final first = await db.getMoment('local-conflict-2', userId: 'user-a');
      final second = await db.getMoment('local-conflict-3', userId: 'user-a');
      expect(first, isNotNull);
      expect(first!.content, 'remote resolved A');
      expect(first.syncStatus, SyncStatus.synced);
      expect(second, isNotNull);
      expect(second!.content, 'local conflict B');
      expect(second.syncStatus, SyncStatus.conflict);
    });
  });
}

typedef _ApiHandler = Future<ApiCallResult> Function({
  required String path,
  dynamic data,
});

typedef _GetApiHandler = Future<ApiCallResult> Function({
  required String path,
  Map<String, dynamic>? queryParameters,
});

class _FakeMomentApiClient implements MomentApiClient {
  _GetApiHandler? onGet;
  _ApiHandler? onPost;
  _ApiHandler? onPut;

  @override
  Future<ApiCallResult> delete(
    String path, {
    data,
    bool retry = true,
  }) {
    throw UnimplementedError();
  }

  @override
  String? envelopeMessage(dynamic body) {
    if (body is Map) {
      return body['msg']?.toString();
    }
    return null;
  }

  @override
  Future<ApiCallResult> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool retry = true,
  }) async {
    if (onGet != null) {
      return onGet!(path: path, queryParameters: queryParameters);
    }
    return const ApiCallResult(
      statusCode: 200,
      data: {
        'code': 200,
        'msg': 'ok',
        'data': {
          'list': <dynamic>[],
          'total_pages': 1,
        },
      },
    );
  }

  @override
  bool isSuccessEnvelope(dynamic body) {
    return body is Map && body['code'] == 200;
  }

  @override
  Future<ApiCallResult> post(
    String path, {
    data,
    bool retry = true,
  }) async {
    if (onPost == null) {
      throw StateError('unexpected POST: $path');
    }
    return onPost!(path: path, data: data);
  }

  @override
  Future<ApiCallResult> put(
    String path, {
    data,
    bool retry = true,
  }) async {
    if (onPut == null) {
      throw StateError('unexpected PUT: $path');
    }
    return onPut!(path: path, data: data);
  }

  @override
  Map<String, dynamic>? unwrapEnvelopeData(dynamic body) {
    if (body is! Map) {
      return null;
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  @override
  Future<String> uploadMediaFile({
    required String filePath,
    required String mediaType,
  }) {
    throw UnimplementedError();
  }
}

class _FakeMomentDatabase implements MomentDatabase {
  final Map<String, Map<String, MomentRecord>> _recordsByUser = {};

  @override
  Future<void> attachServerIdentity(
    String localId,
    MomentRecord serverRecord, {
    required String userId,
  }) async {
    final bucket = _recordsByUser[userId];
    if (bucket == null) {
      throw StateError('unknown user: $userId');
    }
    bucket[localId] = serverRecord.copyWith(id: localId);
  }

  @override
  Future<void> deleteMoment(String id, {required String userId}) async {
    _recordsByUser[userId]?.remove(id);
  }

  @override
  Future<List<MomentRecord>> getAllMoments({required String userId}) async {
    return _sorted(_recordsByUser[userId]?.values ?? const []);
  }

  @override
  Future<List<MomentRecord>> getConflictMoments(
      {required String userId}) async {
    return _sorted(
      (_recordsByUser[userId]?.values ?? const []).where(
        (record) => record.syncStatus == SyncStatus.conflict,
      ),
    );
  }

  @override
  Future<MomentRecord?> getMoment(String id, {required String userId}) async {
    return _recordsByUser[userId]?[id];
  }

  @override
  Future<MomentRecord?> getMomentByServerId(
    String serverId, {
    required String userId,
  }) async {
    for (final record
        in _recordsByUser[userId]?.values ?? const <MomentRecord>[]) {
      if (record.serverId == serverId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<Map<String, int>> getStatistics({required String userId}) async {
    final all =
        _recordsByUser[userId]?.values.toList() ?? const <MomentRecord>[];
    return {
      'total': all.length,
      'image':
          all.where((record) => record.mediaType == MediaType.image).length,
      'audio':
          all.where((record) => record.mediaType == MediaType.audio).length,
      'video':
          all.where((record) => record.mediaType == MediaType.video).length,
      'text': all.where((record) => record.mediaType == MediaType.text).length,
      'mixed':
          all.where((record) => record.mediaType == MediaType.mixed).length,
    };
  }

  @override
  Future<List<MomentRecord>> getUnsyncedMoments(
      {required String userId}) async {
    return _sorted(
      (_recordsByUser[userId]?.values ?? const []).where(
        (record) =>
            record.syncStatus == SyncStatus.localOnly ||
            record.syncStatus == SyncStatus.pendingUpload,
      ),
    );
  }

  @override
  Future<void> insertMoment(MomentRecord record,
      {required String userId}) async {
    _recordsByUser.putIfAbsent(userId, () => {})[record.id] = record;
  }

  @override
  Future<int> promoteConflictMomentForUpload(
    String id, {
    required String userId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> promoteConflictMomentsForUpload({required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<int> resetAllMomentsSyncFlags({required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSyncedMoment(
    MomentRecord record, {
    required String userId,
  }) async {
    _recordsByUser.putIfAbsent(userId, () => {})[record.id] = record;
  }

  @override
  Future<void> updateMoment(MomentRecord record,
      {required String userId}) async {
    _recordsByUser.putIfAbsent(userId, () => {})[record.id] = record;
  }

  @override
  Future<void> upsertMomentByServerId(
    String serverId,
    MomentRecord serverRecord, {
    required String userId,
  }) async {
    final existing = await getMomentByServerId(serverId, userId: userId);
    final next = serverRecord.copyWith(
      id: existing?.id ?? serverRecord.id,
      serverId: serverId,
    );
    _recordsByUser.putIfAbsent(userId, () => {})[next.id] = next;
  }

  List<MomentRecord> _sorted(Iterable<MomentRecord> records) {
    final items = records.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}
