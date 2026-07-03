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

  group('NotificationService.fireTimeFor (lead 클램프)', () {
    final now = DateTime(2026, 7, 3, 12, 0);

    test('마감 없으면 null', () {
      expect(
        NotificationService.fireTimeFor(null, const Duration(minutes: 30), now),
        isNull,
      );
    });
    test('마감이 이미 지났으면 null', () {
      expect(
        NotificationService.fireTimeFor(
            DateTime(2026, 7, 3, 11), Duration.zero, now),
        isNull,
      );
    });
    test('정상: 마감 - lead 시각에 예약', () {
      expect(
        NotificationService.fireTimeFor(
            DateTime(2026, 7, 3, 14), const Duration(minutes: 30), now),
        DateTime(2026, 7, 3, 13, 30),
      );
    });
    test('lead가 마감을 과거로 밀면 마감 시각으로 클램프(이번 버그)', () {
      // 마감 12:10(10분 뒤) + lead 30분 → 11:40(과거) → 마감 12:10에 알림
      expect(
        NotificationService.fireTimeFor(
            DateTime(2026, 7, 3, 12, 10), const Duration(minutes: 30), now),
        DateTime(2026, 7, 3, 12, 10),
      );
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
