/// 环境配置
class EnvConfig {
  /// API 基础 URL（与 Go 路由 `/v1` 一致；勿使用仅 Vite 代理下的 `/api/v1`）
  ///
  /// **Android**（BlueStacks / AVD / USB 真机）：在电脑上执行 `adb reverse tcp:8080 tcp:8080`
  /// 后再调试。未做 reverse 的 Google AVD 可临时改为 `http://10.0.2.2:8080/v1`。
  /// **Web / Wi‑Fi 真机**：改为电脑局域网 IP，例如 `http://192.168.1.5:8080/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080/v1',
  );

  /// 不带 `/v1` 的服务端根地址，用于访问 `/uploads/**` 等静态资源。
  static String get serverBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final segments = List<String>.from(uri.pathSegments);
    if (segments.isNotEmpty && segments.last == 'v1') {
      segments.removeLast();
    }
    return uri
        .replace(pathSegments: segments)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  /// 连接超时（连错地址时会卡满该时长；登录等已关闭重试）
  static const Duration connectTimeout = Duration(seconds: 15);

  /// 接收超时时间
  static const Duration receiveTimeout = Duration(seconds: 30);
}
