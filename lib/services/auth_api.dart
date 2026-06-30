import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthSession {
  static String? accessToken;
  static String? refreshToken;

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  static bool get isAuthenticated => accessToken != null;

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
