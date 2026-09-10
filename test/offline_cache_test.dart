import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/services/offline_cache.dart';
import 'package:test_front/services/trip_api.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('OfflineCache 저장·조회 왕복', () async {
    await OfflineCache.putTrips('{"data":[]}');
    expect(await OfflineCache.getTrips(), '{"data":[]}');
  });

  test('cachedTrips: 캐시 없으면 빈 리스트', () async {
    expect(await TripApi.cachedTrips(), isEmpty);
  });

  test('cachedTrips: 저장된 응답 body를 파싱', () async {
    const body =
        '{"data":[{"id":"t1","title":"부산 여행","destination":"부산","startDate":"2026-09-10","endDate":"2026-09-12"}]}';
    await OfflineCache.putTrips(body);
    final trips = await TripApi.cachedTrips();
    expect(trips.length, 1);
    expect(trips.first.title, '부산 여행');
    expect(trips.first.destination, '부산');
  });
}
