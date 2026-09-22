import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/services/offline_cache.dart';
import 'package:test_front/services/trip_api.dart';
import 'package:test_front/services/auth_api.dart';
import 'dart:convert';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.accessToken =
        'x.${base64Url.encode(utf8.encode('{"sub":"a@example.com"}'))}.x';
  });
  tearDown(() => AuthSession.accessToken = null);

  test(
    'cache is isolated by account and logout clears only its owner',
    () async {
      await OfflineCache.putTrips('a@example.com', 'private A');
      expect(await OfflineCache.getTrips('b@example.com'), isNull);
      await OfflineCache.putTrips('b@example.com', 'private B');
      await OfflineCache.clearOwner('a@example.com');
      expect(await OfflineCache.getTrips('a@example.com'), isNull);
      expect(await OfflineCache.getTrips('b@example.com'), 'private B');
    },
  );

  test('legacy shared cache is removed on upgrade', () async {
    SharedPreferences.setMockInitialValues({
      'cache_trips': 'private',
      'cache_trip_todos_1': 'private',
    });
    await OfflineCache.clearLegacy();
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('OfflineCache 저장·조회 왕복', () async {
    await OfflineCache.putTrips('a@example.com', '{"data":[]}');
    expect(await OfflineCache.getTrips('a@example.com'), '{"data":[]}');
  });

  test('cachedTrips: 캐시 없으면 빈 리스트', () async {
    expect(await TripApi.cachedTrips(), isEmpty);
  });

  test('cachedTrips: 저장된 응답 body를 파싱', () async {
    const body =
        '{"data":[{"id":"t1","title":"부산 여행","destination":"부산","startDate":"2026-09-10","endDate":"2026-09-12"}]}';
    await OfflineCache.putTrips('a@example.com', body);
    final trips = await TripApi.cachedTrips();
    expect(trips.length, 1);
    expect(trips.first.title, '부산 여행');
    expect(trips.first.destination, '부산');
  });
}
