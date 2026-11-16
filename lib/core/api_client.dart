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
      : _baseUrl = baseUrl ??
            'https://asia-southeast1-do-vui-ai-thuong.cloudfunctions.net/api';

  final String _baseUrl;
  String? _idToken;

  // gắn token sau khi đăng nhập
  void setToken(String? token) => _idToken = token;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final req = await HttpClient().getUrl(uri);
    _applyHeaders(req);
    return _handle(await req.close());
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final req = await HttpClient().postUrl(uri);
    _applyHeaders(req);
    req.write(jsonEncode(body));
    return _handle(await req.close());
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
