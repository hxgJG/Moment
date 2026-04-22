import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/moment_record.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../utils/media_source.dart';

class ApiCallResult {
  final int? statusCode;
  final dynamic data;

  const ApiCallResult({
    required this.statusCode,
    required this.data,
  });
}

abstract class MomentApiClient {
  Future<ApiCallResult> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool retry = true,
  });

  Future<ApiCallResult> post(
    String path, {
    dynamic data,
    bool retry = true,
  });

  Future<ApiCallResult> put(
    String path, {
    dynamic data,
    bool retry = true,
  });

  Future<ApiCallResult> delete(
    String path, {
    dynamic data,
    bool retry = true,
  });

  Future<String> uploadMediaFile({
    required String filePath,
    required String mediaType,
  });

  bool isSuccessEnvelope(dynamic body);
  Map<String, dynamic>? unwrapEnvelopeData(dynamic body);
  String? envelopeMessage(dynamic body);
  String getErrorMessage(DioException error);
}

abstract class MomentDatabase {
  Future<void> insertMoment(MomentRecord record, {required String userId});

  Future<void> deleteMoment(String id, {required String userId});

  Future<void> updateMoment(MomentRecord record, {required String userId});

  Future<List<MomentRecord>> getAllMoments({required String userId});

  Future<MomentRecord?> getMoment(String id, {required String userId});

  Future<Map<String, int>> getStatistics({required String userId});

  Future<List<MomentRecord>> getUnsyncedMoments({required String userId});

  Future<List<MomentRecord>> getConflictMoments({required String userId});

  Future<void> saveSyncedMoment(MomentRecord record, {required String userId});

  Future<int> resetAllMomentsSyncFlags({required String userId});

  Future<int> promoteConflictMomentsForUpload({required String userId});

  Future<int> promoteConflictMomentForUpload(
    String id, {
    required String userId,
  });

  Future<MomentRecord?> getMomentByServerId(
    String serverId, {
    required String userId,
  });

  Future<void> upsertMomentByServerId(
    String serverId,
    MomentRecord serverRecord, {
    required String userId,
  });

  Future<void> attachServerIdentity(
    String localId,
    MomentRecord serverRecord, {
    required String userId,
  });
}

class _ApiServiceAdapter implements MomentApiClient {
  final ApiService _api;

  _ApiServiceAdapter(this._api);

  @override
  Future<ApiCallResult> delete(
    String path, {
    data,
    bool retry = true,
  }) async {
    final response = await _api.delete(
      path,
      data: data,
      retry: retry,
    );
    return ApiCallResult(statusCode: response.statusCode, data: response.data);
  }

  @override
  String? envelopeMessage(dynamic body) => _api.envelopeMessage(body);

  @override
  String getErrorMessage(DioException error) => _api.getErrorMessage(error);

  @override
  Future<ApiCallResult> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool retry = true,
  }) async {
    final response = await _api.get(
      path,
      queryParameters: queryParameters,
      retry: retry,
    );
    return ApiCallResult(statusCode: response.statusCode, data: response.data);
  }

  @override
  bool isSuccessEnvelope(dynamic body) => _api.isSuccessEnvelope(body);

  @override
  Future<ApiCallResult> post(
    String path, {
    data,
    bool retry = true,
  }) async {
    final response = await _api.post(
      path,
      data: data,
      retry: retry,
    );
    return ApiCallResult(statusCode: response.statusCode, data: response.data);
  }

  @override
  Future<ApiCallResult> put(
    String path, {
    data,
    bool retry = true,
  }) async {
    final response = await _api.put(
      path,
      data: data,
      retry: retry,
    );
    return ApiCallResult(statusCode: response.statusCode, data: response.data);
  }

  @override
  Map<String, dynamic>? unwrapEnvelopeData(dynamic body) =>
      _api.unwrapEnvelopeData(body);

  @override
  Future<String> uploadMediaFile({
    required String filePath,
    required String mediaType,
  }) {
    return _api.uploadMediaFile(
      filePath: filePath,
      mediaType: mediaType,
    );
  }
}

class _DatabaseServiceAdapter implements MomentDatabase {
  final DatabaseService _db;

  _DatabaseServiceAdapter(this._db);

  @override
  Future<void> attachServerIdentity(
    String localId,
    MomentRecord serverRecord, {
    required String userId,
  }) {
    return _db.attachServerIdentity(
      localId,
      serverRecord,
      userId: userId,
    );
  }

  @override
  Future<void> deleteMoment(String id, {required String userId}) {
    return _db.deleteMoment(id, userId: userId);
  }

  @override
  Future<List<MomentRecord>> getAllMoments({required String userId}) {
    return _db.getAllMoments(userId: userId);
  }

  @override
  Future<List<MomentRecord>> getConflictMoments({required String userId}) {
    return _db.getConflictMoments(userId: userId);
  }

  @override
  Future<MomentRecord?> getMoment(String id, {required String userId}) {
    return _db.getMoment(id, userId: userId);
  }

  @override
  Future<MomentRecord?> getMomentByServerId(
    String serverId, {
    required String userId,
  }) {
    return _db.getMomentByServerId(serverId, userId: userId);
  }

  @override
  Future<Map<String, int>> getStatistics({required String userId}) {
    return _db.getStatistics(userId: userId);
  }

  @override
  Future<List<MomentRecord>> getUnsyncedMoments({required String userId}) {
    return _db.getUnsyncedMoments(userId: userId);
  }

  @override
  Future<void> insertMoment(MomentRecord record, {required String userId}) {
    return _db.insertMoment(record, userId: userId);
  }

  @override
  Future<int> promoteConflictMomentForUpload(
    String id, {
    required String userId,
  }) {
    return _db.promoteConflictMomentForUpload(id, userId: userId);
  }

  @override
  Future<int> promoteConflictMomentsForUpload({required String userId}) {
    return _db.promoteConflictMomentsForUpload(userId: userId);
  }

  @override
  Future<int> resetAllMomentsSyncFlags({required String userId}) {
    return _db.resetAllMomentsSyncFlags(userId: userId);
  }

  @override
  Future<void> saveSyncedMoment(
    MomentRecord record, {
    required String userId,
  }) {
    return _db.saveSyncedMoment(record, userId: userId);
  }

  @override
  Future<void> updateMoment(MomentRecord record, {required String userId}) {
    return _db.updateMoment(record, userId: userId);
  }

  @override
  Future<void> upsertMomentByServerId(
    String serverId,
    MomentRecord serverRecord, {
    required String userId,
  }) {
    return _db.upsertMomentByServerId(
      serverId,
      serverRecord,
      userId: userId,
    );
  }
}

/// 记录状态管理Provider
class MomentProvider extends ChangeNotifier {
  final MomentDatabase _dbService;
  final MomentApiClient _api;
  final Uuid _uuid;
  final bool _autoFetchOnBind;

  MomentProvider({
    MomentDatabase? dbService,
    MomentApiClient? api,
    Uuid? uuid,
    bool autoFetchOnBind = true,
  })  : _dbService = dbService ?? _DatabaseServiceAdapter(DatabaseService()),
        _api = api ?? _ApiServiceAdapter(ApiService()),
        _uuid = uuid ?? const Uuid(),
        _autoFetchOnBind = autoFetchOnBind;

  /// 默认每页数量
  static const int pageSize = 20;

  List<MomentRecord> _moments = [];
  Map<String, int> _statistics = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _currentUserId;
  DateTime? _lastUploadAt;
  DateTime? _lastFetchAt;
  String? _lastUploadError;
  String? _lastFetchError;
  String? _activeSyncLabel;

  /// 所有记录
  List<MomentRecord> get moments => _moments;

  /// 统计数据
  Map<String, int> get statistics => _statistics;

  /// 加载状态
  bool get isLoading => _isLoading;

  /// 加载更多状态
  bool get isLoadingMore => _isLoadingMore;

  /// 同步状态
  bool get isSyncing => _isSyncing;
  String? get activeSyncLabel => _activeSyncLabel;
  DateTime? get lastUploadAt => _lastUploadAt;
  DateTime? get lastFetchAt => _lastFetchAt;
  String? get lastUploadError => _lastUploadError;
  String? get lastFetchError => _lastFetchError;

  /// 最近一次同步结果（便于 UI 提示）
  int get lastSyncUploaded => _lastSyncUploaded;
  int get lastSyncFailed => _lastSyncFailed;

  int _lastSyncUploaded = 0;
  int _lastSyncFailed = 0;

  /// 是否有更多数据
  bool get hasMore => _hasMore;

  /// 错误信息
  String? get error => _error;

  /// 记录总数
  int get totalCount => _statistics['total'] ?? 0;
  int get unsyncedCount => _moments
      .where(
        (m) =>
            m.syncStatus == SyncStatus.localOnly ||
            m.syncStatus == SyncStatus.pendingUpload,
      )
      .length;
  int get conflictCount =>
      _moments.where((m) => m.syncStatus == SyncStatus.conflict).length;

  /// 初始化 - 加载所有记录和统计
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = false;
    notifyListeners();

    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      _moments = [];
      _statistics = {};
      _isSyncing = false;
      _isLoadingMore = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await _reloadLocalData(userId);
    } catch (e) {
      _error = '加载数据失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 绑定当前登录用户；切换账号时自动重载该账号的本地数据
  Future<void> bindUser(String? userId) async {
    final normalized = (userId != null && userId.isNotEmpty) ? userId : null;
    if (_currentUserId == normalized) {
      return;
    }
    _currentUserId = normalized;
    await initialize();
    if (_autoFetchOnBind && normalized != null) {
      unawaited(fetchFromServer(silent: true));
    }
  }

  /// 加载更多记录
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_currentUserId == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      // 尝试从服务器加载更多
      final response = await _api.get(
        '/moments',
        queryParameters: {
          'page': nextPage,
          'page_size': pageSize,
        },
        retry: false, // 分页请求不重试
      );

      final page = _api.unwrapEnvelopeData(response.data);
      final List<dynamic> rawList = _pageListFromData(page);
      final newMoments = rawList
          .map((e) =>
              MomentRecord.fromApiMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (newMoments.isNotEmpty) {
        _moments.addAll(newMoments);
        _currentPage = nextPage;
        _hasMore = newMoments.length >= pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('加载更多失败: $e');
      // 加载更多失败时不显示错误，保持现有数据
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// 添加记录
  Future<bool> addMoment({
    required String content,
    required MediaType mediaType,
    required List<String> mediaPaths,
  }) async {
    try {
      if (_currentUserId == null) {
        _error = '当前未登录';
        notifyListeners();
        return false;
      }

      final record = MomentRecord(
        id: _uuid.v4(),
        content: content,
        createdAt: DateTime.now(),
        mediaType: mediaType,
        mediaPaths: mediaPaths,
        synced: false,
        syncStatus: SyncStatus.localOnly,
      );

      await _dbService.insertMoment(
        record,
        userId: _currentUserId!,
      );

      // 重新加载数据
      await _reloadLocalData(_currentUserId!);

      notifyListeners();
      return true;
    } catch (e) {
      _error = '添加记录失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 删除记录
  Future<bool> deleteMoment(String id) async {
    try {
      if (_currentUserId == null) {
        _error = '当前未登录';
        notifyListeners();
        return false;
      }

      // 获取记录以删除相关媒体文件
      final record = await _dbService.getMoment(id, userId: _currentUserId!);
      if (record != null) {
        if (record.hasServerCopy) {
          await _api.delete('/moments/${record.serverId}');
        }
        // 删除媒体文件
        for (final path in record.mediaPaths) {
          if (!isLocalMediaPath(path)) {
            continue;
          }
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('删除媒体文件失败: $e');
          }
        }
      }

      await _dbService.deleteMoment(id, userId: _currentUserId!);

      // 重新加载数据
      await _reloadLocalData(_currentUserId!);

      notifyListeners();
      return true;
    } catch (e) {
      _error = '删除记录失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 更新记录
  Future<bool> updateMoment(MomentRecord record) async {
    try {
      if (_currentUserId == null) {
        _error = '当前未登录';
        notifyListeners();
        return false;
      }

      final existing =
          await _dbService.getMoment(record.id, userId: _currentUserId!);
      final serverId = existing?.serverId ?? record.serverId;
      final hasServerCopy = serverId != null && serverId.isNotEmpty;
      final updatedRecord = MomentRecord(
        id: record.id,
        serverId: serverId,
        content: record.content,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
        mediaType: record.mediaType,
        mediaPaths: record.mediaPaths,
        synced: false,
        syncStatus: existing?.syncStatus == SyncStatus.conflict
            ? SyncStatus.conflict
            : (hasServerCopy ? SyncStatus.pendingUpload : SyncStatus.localOnly),
        lastSyncedAt: existing?.lastSyncedAt,
        conflictRemoteUpdatedAt: existing?.conflictRemoteUpdatedAt,
      );

      await _dbService.updateMoment(updatedRecord, userId: _currentUserId!);

      // 重新加载数据
      await _reloadLocalData(_currentUserId!);

      notifyListeners();
      return true;
    } catch (e) {
      _error = '更新记录失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 获取单条记录
  MomentRecord? getMomentById(String id) {
    try {
      return _moments.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 同步数据到服务器；返回是否至少有一条成功上传
  Future<bool> syncToServer() async {
    if (_isSyncing) return false;
    if (_currentUserId == null) return false;

    _isSyncing = true;
    _activeSyncLabel = '正在上传到云端';
    _lastSyncUploaded = 0;
    _lastSyncFailed = 0;
    _lastUploadError = null;
    notifyListeners();

    try {
      final userId = _currentUserId!;
      final unsyncedRecords =
          await _dbService.getUnsyncedMoments(userId: userId);

      for (final record in unsyncedRecords) {
        try {
          final mediaPaths = await _prepareRemoteMediaPaths(record);
          final payload = <String, dynamic>{
            'content': record.content,
            'media_type': record.mediaType.name,
            'media_paths': mediaPaths,
          };
          if (!record.hasServerCopy) {
            payload['client_id'] = record.id;
          }
          final response = record.hasServerCopy
              ? await _api.put('/moments/${record.serverId}', data: payload)
              : await _api.post('/moments', data: payload);
          final ok = _api.isSuccessEnvelope(response.data);
          if (ok) {
            final data = _api.unwrapEnvelopeData(response.data);
            if (data != null) {
              final remoteServer = MomentRecord.fromApiMap(data);
              final server = remoteServer.copyWith(
                id: record.id,
                serverId: remoteServer.serverId,
                synced: true,
                syncStatus: SyncStatus.synced,
                lastSyncedAt: DateTime.now(),
              );
              await _dbService.attachServerIdentity(
                record.id,
                server,
                userId: userId,
              );
            } else {
              if (!record.hasServerCopy) {
                throw StateError('服务端未返回新建记录的 ID');
              }
              await _dbService.saveSyncedMoment(
                record.copyWith(
                  synced: true,
                  syncStatus: SyncStatus.synced,
                  lastSyncedAt: DateTime.now(),
                  clearConflictRemoteUpdatedAt: true,
                ),
                userId: userId,
              );
            }
            _lastSyncUploaded++;
          } else {
            _lastSyncFailed++;
            final msg = _api.envelopeMessage(response.data);
            _lastUploadError = msg ?? '上传失败';
            debugPrint(
              '同步记录 ${record.id} 失败: HTTP ${response.statusCode} msg=$msg',
            );
          }
        } catch (e) {
          _lastSyncFailed++;
          _lastUploadError = _friendlyErrorMessage(
            e,
            fallback: '上传失败，请稍后重试',
          );
          debugPrint('同步记录 ${record.id} 失败: $e');
        }
      }

      await _reloadLocalData(userId);
      _lastUploadAt = DateTime.now();

      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return _lastSyncUploaded > 0;
    } catch (e) {
      debugPrint('同步失败: $e');
      _lastUploadError = _friendlyErrorMessage(
        e,
        fallback: '同步失败，请稍后重试',
      );
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return false;
    }
  }

  /// 全部标为未同步（修复历史误标后重新上传）
  Future<int> resetAllMomentsSyncFlags() async {
    if (_currentUserId == null) {
      return 0;
    }
    final n =
        await _dbService.resetAllMomentsSyncFlags(userId: _currentUserId!);
    await _reloadLocalData(_currentUserId!);
    notifyListeners();
    return n;
  }

  /// 将冲突记录改为待上传，表示用户确认以本地为准覆盖云端
  Future<int> promoteConflictMomentsForUpload() async {
    if (_currentUserId == null) {
      return 0;
    }
    final count = await _dbService.promoteConflictMomentsForUpload(
        userId: _currentUserId!);
    await _reloadLocalData(_currentUserId!);
    notifyListeners();
    return count;
  }

  /// 将单条冲突记录改为待上传，表示用户确认以本地为准覆盖云端
  Future<bool> promoteConflictMomentForUpload(String id) async {
    if (_currentUserId == null) {
      return false;
    }
    final count = await _dbService.promoteConflictMomentForUpload(
      id,
      userId: _currentUserId!,
    );
    if (count <= 0) {
      return false;
    }
    await _reloadLocalData(_currentUserId!);
    notifyListeners();
    return true;
  }

  /// 使用最新云端版本覆盖本地冲突记录
  Future<int> resolveConflictMomentsWithRemote() async {
    if (_isSyncing) return 0;
    if (_currentUserId == null) return 0;

    _isSyncing = true;
    _activeSyncLabel = '正在使用云端版本解决冲突';
    _lastFetchError = null;
    notifyListeners();

    try {
      final userId = _currentUserId!;
      final remoteMoments = await _fetchAllRemoteMoments();
      final remoteByServerId = {
        for (final item in remoteMoments)
          if (item.serverId != null && item.serverId!.isNotEmpty)
            item.serverId!: item,
      };
      final conflictMoments =
          await _dbService.getConflictMoments(userId: userId);

      var resolved = 0;
      for (final local in conflictMoments) {
        final serverId = local.serverId;
        if (serverId == null || serverId.isEmpty) {
          continue;
        }
        final remote = remoteByServerId[serverId];
        if (remote == null) {
          continue;
        }

        await _deleteLocalMediaFiles(local.mediaPaths);
        await _dbService.saveSyncedMoment(
          remote.copyWith(
            id: local.id,
            serverId: serverId,
            synced: true,
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now(),
            clearConflictRemoteUpdatedAt: true,
          ),
          userId: userId,
        );
        resolved++;
      }

      await _reloadLocalData(userId);
      _lastFetchAt = DateTime.now();
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return resolved;
    } catch (e) {
      debugPrint('使用云端版本解决冲突失败: $e');
      _lastFetchError = _friendlyErrorMessage(
        e,
        fallback: '同步失败，请稍后重试',
      );
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return 0;
    }
  }

  /// 使用单条最新云端版本覆盖本地冲突记录
  Future<bool> resolveConflictMomentWithRemote(String id) async {
    if (_isSyncing) return false;
    if (_currentUserId == null) return false;

    _isSyncing = true;
    _activeSyncLabel = '正在使用云端版本解决当前冲突';
    _lastFetchError = null;
    notifyListeners();

    try {
      final userId = _currentUserId!;
      final local = await _dbService.getMoment(id, userId: userId);
      if (local == null || local.syncStatus != SyncStatus.conflict) {
        _isSyncing = false;
        _activeSyncLabel = null;
        notifyListeners();
        return false;
      }

      final serverId = local.serverId;
      if (serverId == null || serverId.isEmpty) {
        _isSyncing = false;
        _activeSyncLabel = null;
        notifyListeners();
        return false;
      }

      final remote = await _fetchRemoteMoment(serverId);
      await _deleteLocalMediaFiles(local.mediaPaths);
      await _dbService.saveSyncedMoment(
        remote.copyWith(
          id: local.id,
          serverId: serverId,
          synced: true,
          syncStatus: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
        ),
        userId: userId,
      );

      await _reloadLocalData(userId);
      _lastFetchAt = DateTime.now();
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('使用云端版本解决单条冲突失败: $e');
      _lastFetchError = _friendlyErrorMessage(
        e,
        fallback: '同步失败，请稍后重试',
      );
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return false;
    }
  }

  /// 从服务器拉取数据并合并
  Future<bool> fetchFromServer({bool silent = false}) async {
    if (_isSyncing) return false;
    if (_currentUserId == null) return false;

    _isSyncing = true;
    _activeSyncLabel = silent ? '正在刷新云端数据' : '正在从云端拉取';
    _lastFetchError = null;
    notifyListeners();

    try {
      final remoteMoments = await _fetchAllRemoteMoments();

      // 合并数据：已同步记录以远端为准；本地未同步记录保留
      await _mergeMoments(remoteMoments);

      // 重新加载数据
      await _reloadLocalData(_currentUserId!);
      _lastFetchAt = DateTime.now();

      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('拉取数据失败: $e');
      _lastFetchError = _friendlyErrorMessage(
        e,
        fallback: '拉取失败，请稍后重试',
      );
      _isSyncing = false;
      _activeSyncLabel = null;
      notifyListeners();
      return false;
    }
  }

  /// 合并本地和远程数据
  Future<void> _mergeMoments(List<MomentRecord> remoteMoments) async {
    if (_currentUserId == null) return;

    final localMoments =
        await _dbService.getAllMoments(userId: _currentUserId!);
    final remoteServerIds = {
      for (final item in remoteMoments)
        if (item.serverId != null && item.serverId!.isNotEmpty) item.serverId!,
    };
    final localByServerId = {
      for (final m in localMoments)
        if (m.hasServerCopy) m.serverId!: m,
    };

    for (final remote in remoteMoments) {
      final serverId = remote.serverId;
      if (serverId == null || serverId.isEmpty) {
        continue;
      }
      final local = localByServerId[serverId];
      if (local == null) {
        await _dbService.upsertMomentByServerId(
          serverId,
          remote.copyWith(
            id: _remoteLocalId(serverId),
            serverId: serverId,
            synced: true,
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now(),
          ),
          userId: _currentUserId!,
        );
        localByServerId[serverId] = remote;
        continue;
      }

      if (!local.synced) {
        if (_shouldMarkConflict(local, remote)) {
          await _dbService.saveSyncedMoment(
            local.copyWith(
              synced: false,
              syncStatus: SyncStatus.conflict,
              conflictRemoteUpdatedAt: remote.updatedAt ?? remote.createdAt,
            ),
            userId: _currentUserId!,
          );
        }
        continue;
      }

      if (_momentNeedsRemoteUpdate(local, remote)) {
        await _dbService.saveSyncedMoment(
          remote.copyWith(
            id: local.id,
            serverId: serverId,
            synced: true,
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now(),
            clearConflictRemoteUpdatedAt: true,
          ),
          userId: _currentUserId!,
        );
      }
    }

    for (final local in localMoments) {
      final serverId = local.serverId;
      if (!local.synced || serverId == null || serverId.isEmpty) {
        continue;
      }
      if (remoteServerIds.contains(serverId)) {
        continue;
      }
      await _deleteLocalMediaFiles(local.mediaPaths);
      await _dbService.deleteMoment(local.id, userId: _currentUserId!);
    }
  }

  /// 获取未同步记录数
  Future<int> getUnsyncedCount() async {
    if (_currentUserId == null) {
      return 0;
    }
    final unsynced = await _dbService.getUnsyncedMoments(
      userId: _currentUserId!,
    );
    return unsynced.length;
  }

  Future<void> _reloadLocalData(String userId) async {
    _moments = await _dbService.getAllMoments(userId: userId);
    _statistics = await _dbService.getStatistics(userId: userId);
    _hasMore = false;
  }

  Future<List<String>> _prepareRemoteMediaPaths(MomentRecord record) async {
    final uploadedPaths = <String>[];
    for (final path in record.mediaPaths) {
      if (isAbsoluteMediaUrl(path)) {
        uploadedPaths.add(path);
        continue;
      }
      if (isServerRelativeMediaPath(path)) {
        uploadedPaths.add(resolveMediaUrl(path));
        continue;
      }
      uploadedPaths.add(
        await _api.uploadMediaFile(
          filePath: path,
          mediaType: _uploadMediaTypeForPath(path, record.mediaType),
        ),
      );
    }
    return uploadedPaths;
  }

  Future<void> _deleteLocalMediaFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        await deleteLocalMediaFileIfExists(path);
      } catch (e) {
        debugPrint('删除本地媒体文件失败: $e');
      }
    }
  }

  String _uploadMediaTypeForPath(String path, MediaType fallback) {
    if (isImageMediaPath(path)) return 'image';
    if (isAudioMediaPath(path)) return 'audio';
    if (isVideoMediaPath(path)) return 'video';

    switch (fallback) {
      case MediaType.image:
        return 'image';
      case MediaType.audio:
        return 'audio';
      case MediaType.video:
        return 'video';
      case MediaType.text:
      case MediaType.mixed:
        return 'image';
    }
  }

  Future<List<MomentRecord>> _fetchAllRemoteMoments() async {
    const remotePageSize = 100;
    var page = 1;
    final remoteMoments = <MomentRecord>[];

    while (true) {
      final response = await _api.get(
        '/moments',
        queryParameters: {
          'page': page,
          'page_size': remotePageSize,
        },
      );
      final pageData = _api.unwrapEnvelopeData(response.data);
      final rawList = _pageListFromData(pageData);
      remoteMoments.addAll(
        rawList.map(
          (e) => MomentRecord.fromApiMap(Map<String, dynamic>.from(e as Map)),
        ),
      );

      final totalPages = _pageInt(pageData?['total_pages']);
      if (rawList.isEmpty || (totalPages != null && page >= totalPages)) {
        break;
      }
      if (rawList.length < remotePageSize) {
        break;
      }
      page++;
    }

    return remoteMoments;
  }

  Future<MomentRecord> _fetchRemoteMoment(String serverId) async {
    final response = await _api.get('/moments/$serverId');
    final data = _api.unwrapEnvelopeData(response.data);
    if (data == null) {
      throw StateError('服务端未返回时光详情');
    }
    return MomentRecord.fromApiMap(data);
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is DioException) {
      return _api.getErrorMessage(error);
    }
    final raw = error.toString().trim();
    if (raw.isEmpty || raw.length > 120) {
      return fallback;
    }
    return raw;
  }

  bool _momentNeedsRemoteUpdate(MomentRecord local, MomentRecord remote) {
    if (local.content != remote.content) return true;
    if (local.mediaType != remote.mediaType) return true;
    if (local.mediaPaths.length != remote.mediaPaths.length) return true;
    for (var i = 0; i < local.mediaPaths.length; i++) {
      if (local.mediaPaths[i] != remote.mediaPaths[i]) return true;
    }
    return local.updatedAt != remote.updatedAt;
  }

  bool _shouldMarkConflict(MomentRecord local, MomentRecord remote) {
    if (!local.hasServerCopy || local.synced) {
      return false;
    }
    if (local.syncStatus == SyncStatus.conflict) {
      return true;
    }

    final lastSyncedAt = local.lastSyncedAt;
    final remoteUpdatedAt = remote.updatedAt ?? remote.createdAt;
    if (lastSyncedAt == null || !remoteUpdatedAt.isAfter(lastSyncedAt)) {
      return false;
    }

    return _momentNeedsRemoteUpdate(
      local.copyWith(
        synced: true,
        syncStatus: SyncStatus.synced,
        clearConflictRemoteUpdatedAt: true,
      ),
      remote,
    );
  }

  String _remoteLocalId(String serverId) {
    return 'remote_$serverId';
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// 分页接口的 list 字段；兼容旧版误把 data 当数组
List<dynamic> _pageListFromData(Map<String, dynamic>? data) {
  if (data == null) return [];
  final list = data['list'];
  if (list is List) return list;
  return [];
}

int? _pageInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
