import 'package:shared_preferences/shared_preferences.dart';

/// 오프라인 폴백용 원본 응답 JSON 캐시(여행 중 데이터 없을 때 읽기).
/// 모델 toJson 없이 서버 응답 body를 그대로 저장 → 파싱 왕복이 정확.
class OfflineCache {
  static const _tripsKey = 'cache_trips';
  static String _todosKey(String tripId) => 'cache_trip_todos_$tripId';

  static Future<void> putTrips(String body) => _put(_tripsKey, body);
  static Future<String?> getTrips() => _get(_tripsKey);

  static Future<void> putTripTodos(String tripId, String body) =>
      _put(_todosKey(tripId), body);
  static Future<String?> getTripTodos(String tripId) => _get(_todosKey(tripId));

  static Future<void> _put(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  static Future<String?> _get(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(key);
  }
}
