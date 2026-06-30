import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'auth_api.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 백엔드(Spring) server.port=8080 에 정렬. dart-define API_BASE_URL 로 오버라이드 가능.
  defaultValue: 'http://localhost:8080',
);

/// 공유 HTTP 클라이언트.
/// - 네트워크 오류 시 백오프 재시도(Render 콜드스타트 견디기, 최대 6회 ≈ 1분)
/// - 401(액세스 토큰 만료) 시 refresh 토큰으로 자동 갱신 후 원요청 1회 재시도
///   → 사용자는 재로그인 없이 계속 로그인 유지. refresh도 실패하면 로그인 화면으로.
final http.Client apiClient = _AuthClient();

class _AuthClient extends http.BaseClient {
  final http.Client _inner = RetryClient(
    http.Client(),
    retries: 6,
    whenError: (_, _) => true,
    delay: (i) => Duration(seconds: 3 * (i + 1)),
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    var response = await _inner.send(_rebuild(request, body));
    if (response.statusCode == 401 && AuthSession.refreshToken != null) {
      if (await AuthSession.tryRefresh()) {
        response = await _inner.send(_rebuild(request, body));
      } else {
        AuthSession.onExpired?.call();
      }
    }
    return response;
  }

  // 재전송용으로 요청 복제 + 현재(갱신된) 액세스 토큰을 헤더에 반영.
  http.Request _rebuild(http.BaseRequest original, List<int> body) {
    final req = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = body;
    final token = AuthSession.accessToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return req;
  }
}
