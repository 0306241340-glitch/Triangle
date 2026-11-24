import 'dart:convert';
import 'dart:io';

import 'package:do_vui_ai_thuong/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late String? authorizationHeader;
  final requests = <String>[];

  setUp(() async {
    authorizationHeader = null;
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      authorizationHeader = request.headers.value(
        HttpHeaders.authorizationHeader,
      );

      if (request.uri.path == '/html') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.html
          ..write('<html><head>Not found</head></html>');
      } else if (request.uri.path == '/admin/items') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'detail': 'Not Found'}));
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'ok': true,
              'data': {'status': 'ok'},
            }),
          );
      }

      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('sends the Firebase ID token as a Bearer token', () async {
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}')
      ..setToken('test-id-token');

    await api.get('/health');

    expect(authorizationHeader, 'Bearer test-id-token');
  });

  test('reports HTML responses as an API deployment error', () async {
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    await expectLater(
      api.get('/html'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              contains('Kiểm tra URL API và trạng thái máy chủ'),
            ),
      ),
    );
  });

  test('explains when a deployed API endpoint is missing', () async {
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    await expectLater(
      api.get('/admin/items'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              contains('API chưa được cập nhật'),
            ),
      ),
    );
  });

  test('supports profile updates and deleting saved records', () async {
    final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');

    await api.put('/me/profile', {'displayName': 'Player'});
    await api.delete('/favorites', query: {'targetId': 'set-1'});

    expect(requests, ['PUT /me/profile', 'DELETE /favorites']);
  });
}
