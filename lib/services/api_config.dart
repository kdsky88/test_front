import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 백엔드(Spring) server.port=8080 에 정렬. dart-define API_BASE_URL 로 오버라이드 가능.
  defaultValue: 'http://localhost:8080',
);

/// 공유 HTTP 클라이언트. 무료 호스팅(Render) 콜드스타트로 첫 연결이 실패할 수 있어
/// 네트워크 오류 시 백오프하며 재시도(약 3·6·9·12·15·18s, 최대 6회 ≈ 1분).
final http.Client apiClient = RetryClient(
  http.Client(),
  retries: 6,
  whenError: (_, _) => true,
  delay: (i) => Duration(seconds: 3 * (i + 1)),
);
