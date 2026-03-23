import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

/// 认证状态管理Provider
class AuthProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  User? _user;
  String? _accessToken;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  /// 当前用户
  User? get user => _user;

  /// 访问令牌
  String? get accessToken => _accessToken;

  /// 是否已登录
  bool get isLoggedIn => _accessToken != null && _user != null;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 错误信息
  String? get error => _error;

  /// 初始化 - 从本地存储恢复登录状态
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _accessToken = await _storage.getAccessToken();
      _user = await _storage.getUserInfo();
    } catch (e) {
      debugPrint('初始化认证状态失败: $e');
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// 后端统一包一层 `{ code, msg, data }`，且错误时 HTTP 也可能为 200
  bool _applyAuthEnvelope(dynamic raw) {
    if (raw == null) {
      _error = '服务器响应数据为空 (CORS 或网络问题)';
      return false;
    }
    if (raw is! Map) {
      _error = '响应格式错误';
      return false;
    }
    final body = Map<String, dynamic>.from(raw);
    final code = body['code'];
    if (code != 200) {
      _error = body['msg']?.toString() ?? '请求失败';
      return false;
    }
    final data = body['data'];
    if (data is! Map) {
      _error = '响应缺少 data';
      return false;
    }
    final dataMap = Map<String, dynamic>.from(data);
    final token = dataMap['access_token'] as String?;
    final userRaw = dataMap['user'];
    if (token == null || userRaw is! Map) {
      _error = '登录/注册数据不完整';
      return false;
    }
    _accessToken = token;
    _user = User.fromJson(Map<String, dynamic>.from(userRaw));
    return true;
  }

  /// 登录
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200 && _applyAuthEnvelope(response.data)) {
        await _storage.setAccessToken(_accessToken!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      if (response.statusCode != 200) {
        _error = 'HTTP ${response.statusCode}';
      } else if (_error == null) {
        _error = '登录失败';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('登录失败: $e');
      _error = '网络错误，请检查网络连接';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 注册
  Future<bool> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post('/auth/register', data: {
        'username': username,
        'password': password,
        'nickname': nickname,
      });

      if (response.statusCode == 200 && _applyAuthEnvelope(response.data)) {
        await _storage.setAccessToken(_accessToken!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      if (response.statusCode != 200) {
        _error = 'HTTP ${response.statusCode}';
      } else if (_error == null) {
        _error = '注册失败';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('注册失败: $e');
      String errorMessage = '操作失败，请重试';
      if (e is DioException) {
        debugPrint('DioException response: ${e.response?.data}');
        debugPrint('DioException type: ${e.type}');
        debugPrint('DioException message: ${e.message}');
        if (e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            errorMessage = data['msg'] ?? data['message'] ?? errorMessage;
          } else if (data is String && data.isNotEmpty) {
            errorMessage = data;
          }
        } else {
          // 根据错误类型生成更详细的错误信息
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
              errorMessage = '连接超时';
              break;
            case DioExceptionType.sendTimeout:
              errorMessage = '发送请求超时';
              break;
            case DioExceptionType.receiveTimeout:
              errorMessage = '接收响应超时';
              break;
            case DioExceptionType.connectionError:
              errorMessage = '无法连接到服务器 (${e.message})';
              break;
            case DioExceptionType.badResponse:
              errorMessage = '服务器错误: ${e.response?.statusCode}';
              break;
            default:
              errorMessage = '请求失败: ${e.message ?? e.type.toString()}';
          }
        }
      } else {
        errorMessage = '错误: $e';
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 清除本地数据
      await _storage.clearAll();

      _accessToken = null;
      _user = null;
    } catch (e) {
      debugPrint('登出失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 更新用户信息
  Future<void> updateUser(User user) async {
    _user = user;
    await _storage.setUserInfo(user);
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
