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

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        _user = User.fromJson(data['user']);

        // 保存到本地
        await _storage.setAccessToken(_accessToken!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['msg'] ?? '登录失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
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

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access_token'];
        _user = User.fromJson(data['user']);

        // 保存到本地
        await _storage.setAccessToken(_accessToken!);
        await _storage.setUserId(_user!.id);
        await _storage.setUserInfo(_user!);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['msg'] ?? '注册失败';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('注册失败: $e');
      _error = '网络错误，请检查网络连接';
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
