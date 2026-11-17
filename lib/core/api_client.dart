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
  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://triangle-api-n25s.onrender.com',
  );
  static const _connectionTimeout = Duration(seconds: 10);
  static const _requestTimeout = Duration(seconds: 60);
  final String _baseUrl;
  String? _idToken;

  // Gắn token sau khi đăng nhập
  void setToken(String? token) => _idToken = token;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      final client = HttpClient()..connectionTimeout = _connectionTimeout;

      final req = await client.getUrl(uri).timeout(_requestTimeout);
      _applyHeaders(req);

      final res = await req.close().timeout(_requestTimeout);
      return await _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final client = HttpClient()..connectionTimeout = _connectionTimeout;

      final req = await client.postUrl(uri).timeout(_requestTimeout);
      _applyHeaders(req);
      req.write(jsonEncode(body));

      final res = await req.close().timeout(_requestTimeout);
      return await _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  void _applyHeaders(HttpClientRequest req) {
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (_idToken != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_idToken');
    }
  }

  // Server trả về {ok: true, data} hoặc {ok: false, error}
  Future<dynamic> _handle(HttpClientResponse res) async {
    final text = await res
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);

    dynamic decoded;

    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw ApiException(
        'API trả về dữ liệu không hợp lệ (HTTP ${res.statusCode}). '
        'Kiểm tra URL API và trạng thái máy chủ.',
        res.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Định dạng phản hồi API không hợp lệ (HTTP ${res.statusCode}).',
        res.statusCode,
      );
    }

    final json = decoded;

    if (res.statusCode >= 200 && res.statusCode < 300 && json['ok'] == true) {
      return json['data'];
    }

    final err = json['error'];

    throw ApiException(
      err is Map ? (err['message']?.toString() ?? 'Lỗi server') : 'Lỗi server',
      res.statusCode,
    );
  }
}
