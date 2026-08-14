import 'dart:typed_data';

import 'package:bunyad/data/api_client.dart';
import 'package:bunyad/global.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone token is good for two years. These pin down the cases where the app
/// must *not* treat a failure as the end of that session — an outage, a
/// restart, a proxy or a captive portal answering for the server.
///
/// The check under test is [ApiClient.onUnauthorized]: whether the client
/// reports "this session is over" at all. Nothing downstream can be careful if
/// this fires wrongly.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.reply);

  final ResponseBody Function(RequestOptions options) reply;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async =>
      reply(options);

  @override
  void close({bool force = false}) {}
}

ApiClient _clientReturning(ResponseBody Function(RequestOptions) reply) {
  final dio = Dio()..httpClientAdapter = _StubAdapter(reply);
  return ApiClient(tokenStore: _MemoryTokenStore(), dio: dio);
}

class _MemoryTokenStore implements TokenStore {
  String? _token = 'a-two-year-token';

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody _html(int status, String body) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );

void main() {
  test('a genuine JSON 401 from the API does report the session is over', () async {
    final client = _clientReturning((_) => _json(401, '{"status":401,"message":"Please sign in."}'));
    final reported = <void>[];
    client.onUnauthorized.listen(reported.add);

    await expectLater(client.get(Api.me), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(reported, hasLength(1));
  });

  test('a captive portal answering 401 in HTML does not', () async {
    // Hotel wifi, an airport, a site router with a login page. It is not the
    // server, and its answer must not cost somebody their session.
    final client = _clientReturning((_) => _html(401, '<html><body>Sign in to WiFi</body></html>'));
    final reported = <void>[];
    client.onUnauthorized.listen(reported.add);

    await expectLater(client.get(Api.me), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(reported, isEmpty, reason: 'only the API may end an API session');
  });

  test('the server being down does not', () async {
    final client = _clientReturning((_) => _html(503, '<html>502 Bad Gateway</html>'));
    final reported = <void>[];
    client.onUnauthorized.listen(reported.add);

    await expectLater(client.get(Api.me), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(reported, isEmpty);
  });

  test('no network at all does not', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'Network is unreachable',
          ));
    final client = ApiClient(tokenStore: _MemoryTokenStore(), dio: dio);
    final reported = <void>[];
    client.onUnauthorized.listen(reported.add);

    await expectLater(
      client.get(Api.me),
      throwsA(isA<ApiException>().having((e) => e.isOffline, 'isOffline', isTrue)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(reported, isEmpty);
  });
}
