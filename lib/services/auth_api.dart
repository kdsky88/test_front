import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthSession {
  static String? accessToken;
  static String? refreshToken;

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  /// refresh까지 실패(=장기 미사용/무효)했을 때 호출 → 앱이 로그인 화면으로.
  static void Function()? onExpired;

  static bool get isAuthenticated => accessToken != null;

  /// 액세스 토큰(JWT)의 sub 클레임 = 내 이메일. 서명 검증 없이 payload만 읽음
  /// (내 화면 표시/공유 필터용). 없거나 파싱 실패 시 null.
  static String? get currentEmail {
    final token = accessToken;
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  // 동시 401에 대해 refresh를 1회만 수행(토큰 회전 경쟁 방지).
  static Future<bool>? _refreshInFlight;

  /// 401 발생 시: 저장된 refresh 토큰으로 새 토큰 발급. 성공 true.
  /// 동시 호출은 같은 요청을 공유. 실패하면 세션을 비움.
  static Future<bool> tryRefresh() {
    return _refreshInFlight ??= _refreshOnce().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<bool> _refreshOnce() async {
    final rt = refreshToken;
    if (rt == null) return false;
    try {
      update(await AuthApi.refresh(rt));
      return true;
    } catch (_) {
      clear();
      return false;
    }
  }

  /// 앱 시작 시 저장된 토큰을 메모리로 복원 (main()에서 await).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_kAccess);
    refreshToken = prefs.getString(_kRefresh);
  }

  static void update(TokenResponse token) {
    accessToken = token.accessToken;
    refreshToken = token.refreshToken;
    _persist(); // 메모리는 즉시, 저장은 비동기(앱 동작 막지 않음)
  }

  static void clear() {
    accessToken = null;
    refreshToken = null;
    _persist();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final access = accessToken;
    final refresh = refreshToken;
    await (access == null
        ? prefs.remove(_kAccess)
        : prefs.setString(_kAccess, access));
    await (refresh == null
        ? prefs.remove(_kRefresh)
        : prefs.setString(_kRefresh, refresh));
  }
}

class AuthApi {
  static Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    return _postAuth('/api/auth/login', {'email': email, 'password': password});
  }

  static Future<TokenResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _postAuth('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  /// 비밀번호 변경(로그인 필요). 성공 204. 현재 비번 오답은 백엔드가 400을 주므로
  /// apiClient의 401→refresh 경로를 타지 않음.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.post(
      Uri.parse('$apiBaseUrl/api/auth/password'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode == 204) return;
    throw AuthException(_parseErrorMessage(response));
  }

  /// refresh 토큰으로 새 access/refresh 발급. apiClient(자동 refresh 래퍼)가 아닌
  /// 순수 http로 호출해 401→refresh 무한루프를 방지.
  static Future<TokenResponse> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/refresh'),
      headers: {'Authorization': 'Bearer $refreshToken'},
    );
    if (response.statusCode == 200) {
      return TokenResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw AuthException(_parseErrorMessage(response));
  }

  static Future<TokenResponse> _postAuth(
    String path,
    Map<String, String> body,
  ) async {
    final response = await apiClient.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return TokenResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw AuthException(_parseErrorMessage(response));
  }

  static String _parseErrorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String? ?? '인증에 실패했습니다.';
      }
      return json['message'] as String? ?? '인증에 실패했습니다.';
    } catch (_) {
      return '인증에 실패했습니다.';
    }
  }
}

class TokenResponse {
  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;
}
