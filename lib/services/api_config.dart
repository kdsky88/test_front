const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 백엔드(Spring) server.port=8080 에 정렬. dart-define API_BASE_URL 로 오버라이드 가능.
  defaultValue: 'http://localhost:8080',
);
