import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/services/api_config.dart';
import 'package:test_front/services/auth_api.dart';

TokenResponse token(String value) => TokenResponse(
  accessToken: value,
  refreshToken: 'refresh-$value',
  tokenType: 'Bearer',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.clear();
  });
  tearDown(() {
    AuthSession.refreshRequest = AuthApi.refresh;
  });

  test('POST is never retried after a lost response', () async {
    var attempts = 0;
    final client = AuthClient(
      inner: MockClient((request) async {
        if (request.url.path == '/api/health') return http.Response('ok', 200);
        attempts++;
        throw http.ClientException('response lost');
      }),
      delay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    await expectLater(
      client.post(Uri.parse('https://example.test/trips')),
      throwsA(isA<http.ClientException>()),
    );
    expect(attempts, 1);
  });

  test('a write wakes the sleeping backend first, but only once', () async {
    final calls = <String>[];
    final client = AuthClient(
      inner: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        return http.Response('', 200);
      }),
      delay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    await client.post(Uri.parse('https://example.test/trips'));
    await client.post(Uri.parse('https://example.test/trips'));
    expect(calls, [
      'GET /api/health', // 잠들었을 수 있으니 먼저 깨움
      'POST /trips',
      'POST /trips', // 방금 응답을 받았으니 다시 깨우지 않음
    ]);
  });

  test('GET retries a temporary network failure', () async {
    var attempts = 0;
    final client = AuthClient(
      inner: MockClient((_) async {
        if (++attempts == 1) throw http.ClientException('offline');
        return http.Response('ok', 200);
      }),
      delay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    expect(
      (await client.get(Uri.parse('https://example.test/trips'))).statusCode,
      200,
    );
    expect(attempts, 2);
  });

  test('late refresh cannot restore a logged out session', () async {
    final pending = Completer<TokenResponse>();
    AuthSession.update(token('A'));
    AuthSession.refreshRequest = (_) => pending.future;
    final refreshing = AuthSession.tryRefresh();
    AuthSession.clear();
    pending.complete(token('A-new'));
    expect(await refreshing, isFalse);
    expect(AuthSession.isAuthenticated, isFalse);
  });

  test('late refresh cannot replace a new account', () async {
    final pending = Completer<TokenResponse>();
    AuthSession.update(token('A'));
    AuthSession.refreshRequest = (_) => pending.future;
    final refreshing = AuthSession.tryRefresh();
    AuthSession.update(token('B'));
    pending.complete(token('A-new'));
    expect(await refreshing, isFalse);
    expect(AuthSession.accessToken, 'B');
  });

  test(
    'concurrent 401s share refresh and retry with fresh access token',
    () async {
      AuthSession.update(token('old'));
      var refreshes = 0;
      AuthSession.refreshRequest = (_) async {
        refreshes++;
        return token('new');
      };
      final client = AuthClient(
        inner: MockClient(
          (request) async => http.Response(
            '',
            request.headers['Authorization'] == 'Bearer new' ? 200 : 401,
          ),
        ),
      );
      addTearDown(client.close);
      final result = await Future.wait([
        client.get(Uri.parse('https://example.test/one')),
        client.get(Uri.parse('https://example.test/two')),
      ]);
      expect(result.map((r) => r.statusCode), [200, 200]);
      expect(refreshes, 1);
    },
  );
  test('late unauthorized refresh cannot clear a new account', () async {
    final pending = Completer<TokenResponse>();
    AuthSession.update(token('A'));
    AuthSession.refreshRequest = (_) => pending.future;
    final refreshing = AuthSession.tryRefresh();
    AuthSession.update(token('B'));
    pending.completeError(AuthUnauthorized('expired'));
    expect(await refreshing, isFalse);
    expect(AuthSession.accessToken, 'B');
  });

  test('old account HTTP response is rejected after account switch', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    AuthSession.update(token('A'));
    final client = AuthClient(
      inner: MockClient((_) {
        started.complete();
        return pending.future;
      }),
    );
    addTearDown(client.close);
    final response = client.get(Uri.parse('https://example.test/trips'));
    final rejected = expectLater(
      response,
      throwsA(isA<http.ClientException>()),
    );
    await started.future;
    AuthSession.update(token('B'));
    pending.complete(http.Response('private A', 200));
    await rejected;
  });

  test('503 does not retry a creation request', () async {
    var attempts = 0;
    final client = AuthClient(
      inner: MockClient((request) async {
        if (request.url.path == '/api/health') return http.Response('ok', 200);
        attempts++;
        return http.Response('', 503);
      }),
      delay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    expect(
      (await client.post(Uri.parse('https://example.test/trips'))).statusCode,
      503,
    );
    expect(attempts, 1);
  });
}
