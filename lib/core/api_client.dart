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
  ApiClient({String? baseUrl})
    : _baseUrl = baseUrl ?? 'https://quiz-app-api-vm1o.onrender.com/';

  final String _baseUrl;
  String? _idToken;

  // gắn token sau khi đăng nhập
  void setToken(String? token) => _idToken = token;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 60);
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 60));
      _applyHeaders(req);
      final res = await req.close().timeout(const Duration(seconds: 60));
      return await _handle(res);
    } catch (e) {
      throw ApiException('Không thể kết nối máy chủ: $e', 503);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 60);
      final req = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 60));
      _applyHeaders(req);
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 60));
      return await _handle(res);
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

  // server trả {ok: true, data} hoặc {ok: false, error}
  Future<dynamic> _handle(HttpClientResponse res) async {
    final text = await res.transform(utf8.decoder).join();
    final json = jsonDecode(text) as Map<String, dynamic>;
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
