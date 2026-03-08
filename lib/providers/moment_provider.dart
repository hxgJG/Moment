import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/moment_record.dart';
import '../services/database_service.dart';

/// 记录状态管理Provider
class MomentProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<MomentRecord> _moments = [];
  Map<String, int> _statistics = {};
  bool _isLoading = false;
  String? _error;

  /// 所有记录
  List<MomentRecord> get moments => _moments;

  /// 统计数据
  Map<String, int> get statistics => _statistics;

  /// 加载状态
  bool get isLoading => _isLoading;

  /// 错误信息
  String? get error => _error;

  /// 记录总数
  int get totalCount => _statistics['total'] ?? 0;

  /// 初始化 - 加载所有记录和统计
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
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

      await _dbService.insertMoment(record);

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
      await _dbService.updateMoment(record);

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

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
