/// 环境配置
class EnvConfig {
  /// API基础URL
  static const String apiBaseUrl = 'http://localhost:8080/api/v1';

  /// 连接超时时间
  static const Duration connectTimeout = Duration(seconds: 30);

  /// 接收超时时间
  static const Duration receiveTimeout = Duration(seconds: 30);
}
