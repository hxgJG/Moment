import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// 本地存储服务 - 管理token和用户信息
class StorageService {
  static final StorageService _instance = StorageService._internal();

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserInfo = 'user_info';

  SharedPreferences? _prefs;

  factory StorageService() => _instance;

  StorageService._internal();

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取SharedPreferences实例
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // ===== Token管理 =====

  /// 获取访问令牌
  Future<String?> getAccessToken() async {
    final p = await prefs;
    return p.getString(_keyAccessToken);
  }

  /// 设置访问令牌
  Future<void> setAccessToken(String token) async {
    final p = await prefs;
    await p.setString(_keyAccessToken, token);
  }

  /// 获取刷新令牌
  Future<String?> getRefreshToken() async {
    final p = await prefs;
    return p.getString(_keyRefreshToken);
  }

  /// 设置刷新令牌
  Future<void> setRefreshToken(String token) async {
    final p = await prefs;
    await p.setString(_keyRefreshToken, token);
  }

  /// 清除所有token
  Future<void> clearTokens() async {
    final p = await prefs;
    await p.remove(_keyAccessToken);
    await p.remove(_keyRefreshToken);
  }

  // ===== 用户信息 =====

  /// 获取用户ID
  Future<String?> getUserId() async {
    final p = await prefs;
    return p.getString(_keyUserId);
  }

  /// 设置用户ID
  Future<void> setUserId(String userId) async {
    final p = await prefs;
    await p.setString(_keyUserId, userId);
  }

  /// 获取用户信息
  Future<User?> getUserInfo() async {
    final p = await prefs;
    final jsonStr = p.getString(_keyUserInfo);
    if (jsonStr == null) return null;
    try {
      return User.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// 设置用户信息
  Future<void> setUserInfo(User user) async {
    final p = await prefs;
    await p.setString(_keyUserInfo, jsonEncode(user.toJson()));
  }

  /// 清除用户信息
  Future<void> clearUserInfo() async {
    final p = await prefs;
    await p.remove(_keyUserId);
    await p.remove(_keyUserInfo);
  }

  // ===== 清理所有数据 =====

  /// 清除所有存储数据（退出登录时调用）
  Future<void> clearAll() async {
    await clearTokens();
    await clearUserInfo();
  }
}
