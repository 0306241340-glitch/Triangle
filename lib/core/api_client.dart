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

  factory ApiClient({String? baseUrl}) =>
      baseUrl == null ? _instance : ApiClient._internal(baseUrl: baseUrl);

  ApiClient._internal({String? baseUrl})
    : _baseUrl = baseUrl ?? 'https://quiz-app-api-vm1o.onrender.com';

  final String _baseUrl;
  String? _idToken;

  // gắn token sau khi đăng nhập
  void setToken(String? token) => _idToken = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_idToken != null) 'Authorization': 'Bearer $_idToken',
  };

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 60));
      return _handle(res);
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      return _handle(res);
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  // server trả {ok: true, data} hoặc {ok: false, error}
  dynamic _handle(http.Response res) {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
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
