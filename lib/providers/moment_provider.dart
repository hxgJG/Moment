import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/moment_record.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

/// 记录状态管理Provider
class MomentProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _api = ApiService();
  final Uuid _uuid = const Uuid();

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

  /// 是否有更多数据
  bool get hasMore => _hasMore;

  /// 错误信息
  String? get error => _error;

  /// 记录总数
  int get totalCount => _statistics['total'] ?? 0;

  /// 初始化 - 加载所有记录和统计
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      _moments = await _dbService.getAllMoments();
      _statistics = await _dbService.getStatistics();
    } catch (e) {
      _error = '加载数据失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载更多记录
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

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

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final newMoments = data.map((json) => MomentRecord.fromJson(json)).toList();

        if (newMoments.isNotEmpty) {
          _moments.addAll(newMoments);
          _currentPage = nextPage;
          _hasMore = newMoments.length >= pageSize;
        } else {
          _hasMore = false;
        }
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
      final record = MomentRecord(
        id: _uuid.v4(),
        content: content,
        createdAt: DateTime.now(),
        mediaType: mediaType,
        mediaPaths: mediaPaths,
      );

      await _dbService.insertMoment(record, synced: false);

      // 重新加载数据
      _moments = await _dbService.getAllMoments();
      _statistics = await _dbService.getStatistics();

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
      // 获取记录以删除相关媒体文件
      final record = await _dbService.getMoment(id);
      if (record != null) {
        // 删除媒体文件
        for (final path in record.mediaPaths) {
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

      await _dbService.deleteMoment(id);

      // 重新加载数据
      _moments = await _dbService.getAllMoments();
      _statistics = await _dbService.getStatistics();

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
      final updatedRecord = MomentRecord(
        id: record.id,
        content: record.content,
        createdAt: record.createdAt,
        updatedAt: DateTime.now(),
        mediaType: record.mediaType,
        mediaPaths: record.mediaPaths,
      );

      await _dbService.updateMoment(updatedRecord);

      // 重新加载数据
      _moments = await _dbService.getAllMoments();
      _statistics = await _dbService.getStatistics();

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

  /// 同步数据到服务器
  Future<bool> syncToServer() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      // 获取未同步的记录
      final unsyncedRecords = await _dbService.getUnsyncedMoments();

      for (final record in unsyncedRecords) {
        try {
          final response = await _api.post('/moments', data: record.toJson());
          if (response.statusCode == 200 || response.statusCode == 201) {
            // 标记为已同步
            await _dbService.markAsSynced(record.id);
          }
        } catch (e) {
          debugPrint('同步记录 ${record.id} 失败: $e');
        }
      }

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('同步失败: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// 从服务器拉取数据并合并
  Future<bool> fetchFromServer() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      final response = await _api.get('/moments');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final remoteMoments = data.map((json) => MomentRecord.fromJson(json)).toList();

        // 合并数据：以服务器时间最新为准
        await _mergeMoments(remoteMoments);

        // 重新加载数据
        _moments = await _dbService.getAllMoments();
        _statistics = await _dbService.getStatistics();

        _isSyncing = false;
        notifyListeners();
        return true;
      }

      _isSyncing = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('拉取数据失败: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// 合并本地和远程数据
  Future<void> _mergeMoments(List<MomentRecord> remoteMoments) async {
    final localMoments = await _dbService.getAllMoments();

    // 创建本地ID集合
    final localIds = localMoments.map((m) => m.id).toSet();

    // 添加远程独有的记录
    for (final remote in remoteMoments) {
      if (!localIds.contains(remote.id)) {
        await _dbService.insertMoment(remote, synced: true);
      }
    }

    // TODO: 冲突策略 - 以最新时间为准
    // 目前简单处理：远程优先
  }

  /// 获取未同步记录数
  Future<int> getUnsyncedCount() async {
    final unsynced = await _dbService.getUnsyncedMoments();
    return unsynced.length;
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
