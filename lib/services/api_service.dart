import 'package:dio/dio.dart';
import '../config/env.dart';
import 'storage_service.dart';

/// API服务 - 封装Dio实例
class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;
  final StorageService _storage = StorageService();

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试延迟时间（毫秒）
  static const int retryDelay = 1000;

  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: EnvConfig.connectTimeout,
        receiveTimeout: EnvConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  /// 请求拦截器 - 自动附加Authorization头
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 不需要认证的路径
    final noAuthPaths = ['/auth/login', '/auth/register'];
    final isNoAuthPath = noAuthPaths.any((p) => options.path.contains(p));

    if (!isNoAuthPath) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  /// 错误拦截器 - 统一处理401
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401) {
      // Token过期，清除本地数据
      await _storage.clearAll();
      // 可以在这里触发跳转到登录页
      // 实际跳转逻辑在路由守卫中处理
    }
    handler.next(error);
  }

  /// 执行带重试的请求
  Future<Response<T>> _requestWithRetry<T>(
    Future<Response<T>> Function() requestFn,
  ) async {
    int retries = 0;
    DioException? lastError;

    while (retries < maxRetries) {
      try {
        return await requestFn();
      } on DioException catch (e) {
        lastError = e;
        // 仅对网络错误或服务器错误进行重试
        if (_shouldRetry(e)) {
          retries++;
          if (retries < maxRetries) {
            // 指数退避延迟
            await Future.delayed(Duration(milliseconds: retryDelay * retries));
            continue;
          }
        }
        break;
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  /// 判断是否应该重试
  bool _shouldRetry(DioException error) {
    // 网络错误
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    // 服务器错误
    if (error.response?.statusCode != null &&
        error.response!.statusCode! >= 500) {
      return true;
    }
    return false;
  }

  /// 获取友好的错误消息
  String getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送请求超时';
      case DioExceptionType.receiveTimeout:
        return '接收响应超时';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return '登录已过期，请重新登录';
        } else if (statusCode == 403) {
          return '没有权限执行此操作';
        } else if (statusCode == 404) {
          return '请求的资源不存在';
        } else if (statusCode != null && statusCode >= 500) {
          return '服务器错误，请稍后重试';
        }
        return '请求失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络异常，请稍后重试';
    }
  }

  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool retry = true,
  }) async {
    final requestFn = () => _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
        );

    if (retry) {
      return _requestWithRetry(requestFn);
    }
    return requestFn();
  }

  /// POST请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool retry = true,
  }) async {
    final requestFn = () => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );

    if (retry) {
      return _requestWithRetry(requestFn);
    }
    return requestFn();
  }

  /// PUT请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool retry = true,
  }) async {
    final requestFn = () => _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );

    if (retry) {
      return _requestWithRetry(requestFn);
    }
    return requestFn();
  }

  /// DELETE请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool retry = true,
  }) async {
    final requestFn = () => _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        );

    if (retry) {
      return _requestWithRetry(requestFn);
    }
    return requestFn();
  }

  /// 获取Dio实例（用于文件上传等特殊场景）
  Dio get dio => _dio;
}
