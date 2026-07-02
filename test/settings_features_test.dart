import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/services/auth_api.dart';
import 'package:test_front/services/notification_service.dart';

// JWT는 base64url 패딩(=)을 떼므로, 그 형태를 그대로 흉내 낸 토큰.
String _jwtWithSub(String sub) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'sub': sub})}.sig';
}

void main() {
  group('AuthSession.currentEmail (JWT sub 디코딩)', () {
    tearDown(() => AuthSession.accessToken = null);

    test('패딩 없는 JWT에서 sub를 읽는다', () {
      AuthSession.accessToken = _jwtWithSub('me@example.com');
      expect(AuthSession.currentEmail, 'me@example.com');
    });

    test('토큰 없으면 null', () {
      AuthSession.accessToken = null;
      expect(AuthSession.currentEmail, isNull);
    });

    test('망가진 토큰이면 예외 없이 null', () {
      AuthSession.accessToken = 'not-a-jwt';
      expect(AuthSession.currentEmail, isNull);
    });
  });

  group('NotificationService.nextMorning (오늘/내일 경계)', () {
    test('목표 시각 전이면 오늘', () {
      expect(
        NotificationService.nextMorning(DateTime(2026, 7, 3, 6), 8, 0),
        DateTime(2026, 7, 3, 8, 0),
      );
    });
    test('목표 시각 후면 내일', () {
      expect(
        NotificationService.nextMorning(DateTime(2026, 7, 3, 9), 8, 0),
        DateTime(2026, 7, 4, 8, 0),
      );
    });
    test('정확히 목표 시각이면 내일(지금 아님)', () {
      expect(
        NotificationService.nextMorning(DateTime(2026, 7, 3, 8), 8, 0),
        DateTime(2026, 7, 4, 8, 0),
      );
    });
  });
}
