import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../config/env.dart';
import 'storage_service.dart';

/// API服务 - 封装Dio实例
class ApiService {
  static final ApiService _instance = ApiService._internal();
  static const String _skipAuthKey = 'skipAuth';
  static const String _skipRefreshKey = 'skipRefresh';
  static const String _retriedAfterRefreshKey = 'retriedAfterRefresh';
  static const String _retryDataFactoryKey = 'retryDataFactory';

  late final Dio _dio;
  final StorageService _storage = StorageService();
  Future<bool>? _refreshingFuture;

  VoidCallback? onUnauthorized;

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

  bool _isNoAuthPath(String path) {
    const noAuthPaths = ['/auth/login', '/auth/register', '/auth/refresh'];
    return noAuthPaths.any((p) => path.contains(p));
  }

  /// 请求拦截器 - 自动附加Authorization头
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[_skipAuthKey] == true;
    if (!skipAuth && !_isNoAuthPath(options.path)) {
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
    if (!_shouldAttemptRefresh(error)) {
      if (_shouldLogoutAfterError(error)) {
        await _logoutLocally();
      }
      handler.next(error);
      return;
    }

    final refreshed = await _refreshAccessToken();
    if (!refreshed) {
      await _logoutLocally();
      handler.next(error);
      return;
    }

    try {
      final response = await _retryRequest(error.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      if (_shouldLogoutAfterError(retryError)) {
        await _logoutLocally();
      }
      handler.next(retryError);
    }
  }

  bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }

    final options = error.requestOptions;
    if (options.extra[_skipRefreshKey] == true ||
        options.extra[_retriedAfterRefreshKey] == true) {
      return false;
    }

    return !_isNoAuthPath(options.path);
  }

  bool _shouldLogoutAfterError(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }

    final options = error.requestOptions;
    return options.extra[_skipRefreshKey] == true ||
        _isNoAuthPath(options.path);
  }

  Future<void> _logoutLocally() async {
    await _storage.clearAll();
    onUnauthorized?.call();
  }

  Future<bool> _refreshAccessToken() async {
    final existingFuture = _refreshingFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _performRefreshToken();
    _refreshingFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshingFuture, future)) {
        _refreshingFuture = null;
      }
    }
  }

  Future<bool> _performRefreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
        options: Options(
          extra: {
            _skipAuthKey: true,
            _skipRefreshKey: true,
          },
        ),
      );

      final body = response.data;
      if (response.statusCode != 200 || !isSuccessEnvelope(body)) {
        return false;
      }

      final dataMap = unwrapEnvelopeData(body);
      if (dataMap == null) {
        return false;
      }
      final nextAccessToken = dataMap['access_token']?.toString();
      final nextRefreshToken = dataMap['refresh_token']?.toString();
      if (nextAccessToken == null || nextRefreshToken == null) {
        return false;
      }

      await _storage.setAccessToken(nextAccessToken);
      await _storage.setRefreshToken(nextRefreshToken);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<dynamic> _buildRetryData(RequestOptions options) async {
    final factory = options.extra[_retryDataFactoryKey];
    if (factory is Future<dynamic> Function()) {
      return factory();
    }
    if (factory is dynamic Function()) {
      return factory();
    }
    return options.data;
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    final extra = Map<String, dynamic>.from(requestOptions.extra)
      ..[_retriedAfterRefreshKey] = true;

    return _dio.request<dynamic>(
      requestOptions.path,
      data: await _buildRetryData(requestOptions),
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
      options: Options(
        method: requestOptions.method,
        headers: Map<String, dynamic>.from(requestOptions.headers),
        extra: extra,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        listFormat: requestOptions.listFormat,
      ),
    );
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

  bool isSuccessEnvelope(dynamic body) {
    if (body is! Map) {
      return false;
    }
    final code = body['code'];
    return code == 200 || code == 200.0;
  }

  String? envelopeMessage(dynamic body) {
    if (body is! Map) {
      return null;
    }
    final msg = body['msg'] ?? body['message'];
    return msg?.toString();
  }

  Map<String, dynamic>? unwrapEnvelopeData(dynamic body) {
    if (!isSuccessEnvelope(body) || body is! Map) {
      return null;
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool retry = true,
  }) async {
    Future<Response<T>> requestFn() {
      return _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    }

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
    Future<Response<T>> requestFn() {
      return _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    }

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
    Future<Response<T>> requestFn() {
      return _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    }

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
    Future<Response<T>> requestFn() {
      return _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    }

    if (retry) {
      return _requestWithRetry(requestFn);
    }
    return requestFn();
  }

  /// 获取Dio实例（用于文件上传等特殊场景）
  Dio get dio => _dio;

  /// 上传媒体文件并返回可访问 URL
  Future<String> uploadMediaFile({
    required String filePath,
    required String mediaType,
  }) async {
    Future<FormData> buildFormData() async {
      return FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
        ),
        'media_type': mediaType,
      });
    }

    final formData = await buildFormData();

    final response = await _dio.post(
      '/upload',
      data: formData,
      options: Options(
        extra: {
          _retryDataFactoryKey: buildFormData,
        },
      ),
    );
    final body = response.data;
    if (response.statusCode != 200 || !isSuccessEnvelope(body)) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: envelopeMessage(body) ?? 'upload failed',
      );
    }

    final data = unwrapEnvelopeData(body);
    if (data == null || data['url'] == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'upload response missing url',
      );
    }

    return data['url'].toString();
  }
}
