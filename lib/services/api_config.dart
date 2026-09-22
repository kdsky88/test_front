import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'auth_api.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 백엔드(Spring) server.port=8080 에 정렬. dart-define API_BASE_URL 로 오버라이드 가능.
  defaultValue: 'http://localhost:8080',
);

/// 백엔드 콜드스타트 완화: 앱 시작 시(스플래시 동안) health를 미리 때려 Render를 깨운다.
/// fire-and-forget — 실패해도 무시(첫 실제 요청은 apiClient 재시도가 견딤).
void warmBackend() {
  http.get(Uri.parse('$apiBaseUrl/api/health')).ignore();
}

/// 공유 HTTP 클라이언트.
/// - 조회(GET/HEAD/OPTIONS) 요청의 네트워크 오류 시 백오프 재시도(Render 콜드스타트 견디기, 최대 6회 ≈ 1분)
/// - 쓰기 요청은 재시도하지 않는 대신(중복 생성 방지), 한동안 조용했으면 먼저 health로 서버를 깨운다.
/// - 401(액세스 토큰 만료) 시 refresh 토큰으로 자동 갱신 후 원요청 1회 재시도
///   → 사용자는 재로그인 없이 계속 로그인 유지. refresh도 실패하면 로그인 화면으로.
final http.Client apiClient = AuthClient();

class AuthClient extends http.BaseClient {
  AuthClient({http.Client? inner, Duration Function(int)? delay}) {
    _raw = inner ?? http.Client();
    _reads = RetryClient(
      _raw,
      retries: 6,
      whenError: (_, _) => true,
      delay: delay ?? (i) => Duration(seconds: 3 * (i + 1)),
    );
  }
  late final http.Client _raw;
  late final http.Client _reads;

  /// Render 무료 인스턴스는 유휴 15분이면 잠든다. 쓰기는 재시도하지 않으므로(중복 생성 방지)
  /// 마지막 응답이 오래됐으면 재시도가 붙는 health로 먼저 깨운 뒤 보낸다.
  static const _maybeAsleep = Duration(minutes: 10);
  DateTime? _lastResponseAt;

  Future<void> _wakeIfIdle() async {
    final last = _lastResponseAt;
    if (last != null && DateTime.now().difference(last) < _maybeAsleep) return;
    try {
      // 45초 = Render 콜드스타트는 견디되, 오프라인일 때 쓰기가 무한정 안 끝나진 않게.
      await _reads
          .get(Uri.parse('$apiBaseUrl/api/health'))
          .timeout(const Duration(seconds: 45));
      _lastResponseAt = DateTime.now();
    } catch (_) {
      // 깨우기에 실패해도 원 요청은 그대로 시도한다.
    }
  }

  @override
  void close() => _reads.close();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final epoch = AuthSession.generation;
    final body = await request.finalize().toBytes();
    if (epoch != AuthSession.generation) {
      throw http.ClientException('Session changed');
    }
    final isRead = {'GET', 'HEAD', 'OPTIONS'}.contains(request.method);
    if (!isRead) {
      await _wakeIfIdle();
      if (epoch != AuthSession.generation) {
        throw http.ClientException('Session changed');
      }
    }
    final client = isRead ? _reads : _raw;
    var response = await client.send(_rebuild(request, body));
    _lastResponseAt = DateTime.now();
    if (epoch != AuthSession.generation) {
      await response.stream.drain<void>();
      throw http.ClientException('Session changed');
    }
    if (response.statusCode == 401 && AuthSession.refreshToken != null) {
      await response.stream.drain<void>();
      if (await AuthSession.tryRefresh()) {
        response = await client.send(_rebuild(request, body));
        _lastResponseAt = DateTime.now();
      } else {
        response = http.StreamedResponse(const Stream<List<int>>.empty(), 401);
        if (!AuthSession.isAuthenticated) {
          // refresh가 세션을 실제로 비운 경우(=refresh 토큰 무효/만료)에만 로그아웃.
          // 일시 오류로 refresh만 실패한 경우엔 세션 유지(요청은 401로 반환).
          AuthSession.onExpired?.call();
        }
      }
    }
    if (epoch != AuthSession.generation) {
      await response.stream.drain<void>();
      throw http.ClientException('Session changed');
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
