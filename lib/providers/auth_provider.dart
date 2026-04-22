import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

String _messageForAuthException(Object e) {
  if (e is! DioException) {
    return '请求异常: $e';
  }
  final ex = e;
  final data = ex.response?.data;
  if (data is Map) {
    final msg = data['msg'] ?? data['message'];
    if (msg != null) return msg.toString();
  } else if (data is String && data.isNotEmpty) {
    return data;
  }
  switch (ex.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return '连接超时，请确认后端已启动且 API 地址正确';
    case DioExceptionType.receiveTimeout:
      return '接收响应超时';
    case DioExceptionType.connectionError:
      return '无法连接服务器。USB 请 adb reverse tcp:8080 tcp:8080 并使用 127.0.0.1；'
          '模拟器可改为 10.0.2.2；Wi‑Fi 真机请改为电脑局域网 IP（见 lib/config/env.dart）';
    case DioExceptionType.badResponse:
      return '服务器错误: HTTP ${ex.response?.statusCode}';
    default:
      return ex.message ?? '请求失败';
  }
}

/// 认证状态管理Provider
class AuthProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  AuthProvider() {
    _api.onUnauthorized = _handleUnauthorized;
  }

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
      _refreshToken = await _storage.getRefreshToken();
      _user = await _storage.getUserInfo();
    } catch (e) {
      debugPrint('初始化认证状态失败: $e');
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  bool _applyAuthEnvelope(dynamic raw) {
    final dataMap = _api.unwrapEnvelopeData(raw);
    if (dataMap == null) {
      _error = _api.envelopeMessage(raw) ?? '响应格式错误';
      return false;
    }
    final token = dataMap['access_token'] as String?;
    final refreshToken = dataMap['refresh_token'] as String?;
    final userRaw = dataMap['user'];
    if (token == null || refreshToken == null || userRaw is! Map) {
      _error = '登录/注册数据不完整';
      return false;
    }
    _accessToken = token;
    _refreshToken = refreshToken;
    _user = User.fromJson(Map<String, dynamic>.from(userRaw));
    return true;
  }

  Future<void> _persistAuthState() async {
    if (_accessToken == null || _refreshToken == null || _user == null) {
      return;
    }
    await _storage.setAccessToken(_accessToken!);
    await _storage.setRefreshToken(_refreshToken!);
    await _storage.setUserId(_user!.id);
    await _storage.setUserInfo(_user!);
  }

  void _handleUnauthorized() {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    notifyListeners();
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
      final response = await _api.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
        retry: false,
      );

      if (_applyAuthEnvelope(response.data)) {
        await _persistAuthState();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error ??= '登录失败';

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('登录失败: $e');
      _error = _messageForAuthException(e);
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
      final response = await _api.post(
        '/auth/register',
        data: {
          'username': username,
          'password': password,
          'nickname': nickname,
        },
        retry: false,
      );

      if (_applyAuthEnvelope(response.data)) {
        await _persistAuthState();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error ??= '注册失败';

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('注册失败: $e');
      _error = _messageForAuthException(e);
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
      _refreshToken = null;
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
