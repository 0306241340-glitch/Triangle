import 'dart:convert';

import 'package:http/http.dart' as http;

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
    defaultValue: 'https://quiz-app-api-fastapi.onrender.com',
  );

  static const _requestTimeout = Duration(seconds: 60);

  final String _baseUrl;
  String? _idToken;

  void setToken(String? token) {
    _idToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_idToken != null) 'Authorization': 'Bearer $_idToken',
  };

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      final res = await http
          .get(uri, headers: _headers)
          .timeout(_requestTimeout);
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(_requestTimeout);
      return _handle(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  dynamic _handle(http.Response res) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw ApiException(
        'API trả về dữ liệu không hợp lệ (HTTP ${res.statusCode}). Kiểm tra URL API và trạng thái máy chủ',
        res.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Định dạng phản hồi API không hợp lệ (HTTP ${res.statusCode}).',
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
      err is Map
          ? (err['message']?.toString() ?? 'Lỗi máy chủ')
          : 'Lỗi máy chủ',
      res.statusCode,
    );
  }
}
