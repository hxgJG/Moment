/// 环境配置
class EnvConfig {
  /// API 基础 URL（与 Go 路由 `/v1` 一致；勿使用仅 Vite 代理下的 `/api/v1`）
  ///
  /// **Android**（BlueStacks / AVD / USB 真机）：在电脑上执行 `adb reverse tcp:8080 tcp:8080`
  /// 后再调试。未做 reverse 的 Google AVD 可临时改为 `http://10.0.2.2:8080/v1`。
  /// **Web 调试**：使用本机局域网 IP 如 `http://192.168.0.106:8080/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.106:8080/v1',
  );

  /// 连接超时时间
  static const Duration connectTimeout = Duration(seconds: 30);

  /// 接收超时时间
  static const Duration receiveTimeout = Duration(seconds: 30);
}
