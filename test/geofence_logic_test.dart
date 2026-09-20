import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/models/trip.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/services/geofence_logic.dart';
import 'package:test_front/services/notification_prefs.dart';

Trip trip(String id, DateTime? s, DateTime? e) =>
    Trip(id: id, title: 'trip-$id', startDate: s, endDate: e);

Todo todo(String id, String? tripId,
        {double? lat, double? lon, String? place, String title = 'T'}) =>
    Todo(
      id: id,
      title: title,
      completed: false,
      priority: TodoPriority.medium,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tripId: tripId,
      latitude: lat,
      longitude: lon,
      placeName: place,
    );

void main() {
  final now = DateTime(2026, 9, 20, 14);

  group('activeTrips', () {
    test('now가 여행 기간(양끝 포함)에 들면 active', () {
      final trips = [
        trip('a', DateTime(2026, 9, 20), DateTime(2026, 9, 25)), // 시작일 당일
        trip('b', DateTime(2026, 9, 15), DateTime(2026, 9, 20)), // 종료일 당일
        trip('c', DateTime(2026, 9, 10), DateTime(2026, 9, 19)), // 지남
        trip('d', DateTime(2026, 9, 21), DateTime(2026, 9, 25)), // 미래
        trip('e', null, null),                                    // 날짜 없음
      ];
      expect(activeTrips(trips, now).map((t) => t.id).toSet(), {'a', 'b'});
    });
  });

  group('geofencesForActiveTrips', () {
    test('active 여행 + lat/lon 있는 todo만, 이름은 placeName 우선', () {
      final trips = [trip('a', DateTime(2026, 9, 20), DateTime(2026, 9, 25))];
      final todos = [
        todo('t1', 'a', lat: 35.1, lon: 129.0, place: '해운대'),
        todo('t2', 'a', title: '메모만'),          // 좌표 없음 → 제외
        todo('t3', 'z', lat: 1, lon: 1),           // 비-active 여행 → 제외
        todo('t4', 'a', lat: 37.5, lon: 127.0, title: '광장'), // placeName 없음 → title
      ];
      final r = geofencesForActiveTrips(trips, todos, now);
      expect(r.fences.map((f) => f.id).toSet(), {'t1', 't4'});
      expect(r.names['t1'], '해운대');
      expect(r.names['t4'], '광장');
    });
  });

  group('shouldNotify', () {
    test('마지막 알림 없으면 true', () {
      expect(shouldNotify(null, now, const Duration(hours: 6)), isTrue);
    });
    test('쿨다운 이내면 false, 딱 지나면 true', () {
      expect(shouldNotify(now.subtract(const Duration(hours: 5)), now, const Duration(hours: 6)), isFalse);
      expect(shouldNotify(now.subtract(const Duration(hours: 6)), now, const Duration(hours: 6)), isTrue);
    });
  });

  group('NotificationPrefs.nearbyEnabled', () {
    test('기본 false, set 후 load하면 유지', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPrefs.load();
      expect(NotificationPrefs.nearbyEnabled, isFalse);
      await NotificationPrefs.setNearbyEnabled(true);
      await NotificationPrefs.load();
      expect(NotificationPrefs.nearbyEnabled, isTrue);
    });
  });
}
