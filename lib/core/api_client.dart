import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient({String? baseUrl}) {
    return baseUrl == null ? _instance : ApiClient._internal(baseUrl: baseUrl);
  }

  ApiClient._internal({String? baseUrl})
    : _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://triangle-api-n25s.onrender.com',
  );

  static const _connectionTimeout = Duration(seconds: 10);
  static const _requestTimeout = Duration(seconds: 60);

  final String _baseUrl;
  String? _idToken;

  void setToken(String? token) {
    _idToken = token;
  }

  void _applyHeaders(HttpClientRequest req) {
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (_idToken != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_idToken');
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final client = HttpClient()..connectionTimeout = _connectionTimeout;

    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);

      final req = await client.getUrl(uri).timeout(_requestTimeout);

      _applyHeaders(req);

      final res = await req.close().timeout(_requestTimeout);

      return await _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Khong the ket noi may chu: $e', 503);
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = _connectionTimeout;

    try {
      final uri = Uri.parse('$_baseUrl$path');

      final req = await client.postUrl(uri).timeout(_requestTimeout);

      _applyHeaders(req);
      req.write(jsonEncode(body));

      final res = await req.close().timeout(_requestTimeout);

      return await _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Khong the ket noi may chu: $e', 503);
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _handle(HttpClientResponse res) async {
    final responseText = await res
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);

    dynamic decoded;

    try {
      decoded = jsonDecode(responseText);
    } on FormatException {
      throw ApiException(
        'API tra ve du lieu khong hop le (HTTP ${res.statusCode}). '
        'Kiểm tra URL API và trạng thái máy chủ',
        res.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Dinh dang phan hoi API khong hop le (HTTP ${res.statusCode}).',
        res.statusCode,
      );
    }

    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        decoded['ok'] == true) {
      return decoded['data'];
    }

    final err = decoded['error'];

    throw ApiException(
      err is Map ? (err['message']?.toString() ?? 'Loi server') : 'Loi server',
      res.statusCode,
    );
  }
}
