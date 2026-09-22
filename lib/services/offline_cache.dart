import 'package:shared_preferences/shared_preferences.dart';

/// Cache ownership is captured before an HTTP request, never after its response.
class OfflineCache {
  static String _prefix(String owner) =>
      'cache_v2_${Uri.encodeComponent(owner)}_';
  static Future<void> putTrips(String owner, String body) =>
      _put('${_prefix(owner)}trips', body);
  static Future<String?> getTrips(String owner) =>
      _get('${_prefix(owner)}trips');
  static Future<void> putTripTodos(String owner, String tripId, String body) =>
      _put('${_prefix(owner)}todos_$tripId', body);
  static Future<String?> getTripTodos(String owner, String tripId) =>
      _get('${_prefix(owner)}todos_$tripId');

  static Future<void> clearOwner(String owner) async {
    final p = await SharedPreferences.getInstance();
    for (final key
        in p.getKeys().where((k) => k.startsWith(_prefix(owner))).toList()) {
      await p.remove(key);
    }
  }

  static Future<void> clearLegacy() async {
    final p = await SharedPreferences.getInstance();
    for (final key
        in p
            .getKeys()
            .where(
              (k) => k == 'cache_trips' || k.startsWith('cache_trip_todos_'),
            )
            .toList()) {
      await p.remove(key);
    }
  }

  static Future<void> _put(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  static Future<String?> _get(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(key);
  }
}
