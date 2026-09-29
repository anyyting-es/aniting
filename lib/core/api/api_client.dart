import 'package:dio/dio.dart';
import 'package:seanime_app/core/constants/app_constants.dart';

class ApiClient {
  late Dio _dio;
  String _baseUrl = AppConstants.defaultBaseUrl;
  String? _token;

  ApiClient({String? baseUrl, String? token}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
    }
    _token = token;
    _initDio();
  }

  String get _origin {
    final uri = Uri.tryParse(_baseUrl);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portPart';
    }
    return 'http://127.0.0.1:43211';
  }

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': _origin,
          'Referer': '$_origin/',
          if (_token != null && _token!.isNotEmpty) 'X-Seanime-Token': _token,
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Origin'] ??= _origin;
          options.headers['Referer'] ??= '$_origin/';
          if (_token != null && _token!.isNotEmpty) {
            options.headers['X-Seanime-Token'] = _token;
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Log or process error
          return handler.next(error);
        },
      ),
    );
  }

  void updateConfig({required String host, required int port, String? token}) {
    _baseUrl = 'http://$host:$port/api/v1';
    _token = token;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers['Origin'] = _origin;
    _dio.options.headers['Referer'] = '$_origin/';
    if (_token != null) {
      _dio.options.headers['X-Seanime-Token'] = _token;
    } else {
      _dio.options.headers.remove('X-Seanime-Token');
    }
  }

  String get baseUrl => _baseUrl;
  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
}
