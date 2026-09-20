import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import 'geofence_logic.dart';
import 'notification_prefs.dart';
import 'trip_api.dart';

const _kRadiusMeters = 150.0;
const _kLoiteringDelay = Duration(seconds: 60);
const _kCooldown = Duration(hours: 6);
const _kNamesKey = 'geofence_names'; // JSON {id: name}
const _kLastPrefix = 'geofence_last_'; // + id -> epoch millis
const _channelId = 'nearby_places';

/// enabled + 진행중 여행이면 그 여행의 저장 장소로 지오펜스 등록, 아니면 전부 해제.
/// 앱-열림 기반: main·설정 토글에서 호출. 실패는 조용히 무시(앱 방해 X).
Future<void> syncNearbyGeofences() async {
  if (kIsWeb) return; // 웹은 지오펜싱 불가
  try {
    if (!NotificationPrefs.nearbyEnabled) {
      await clearGeofences();
      return;
    }
    final trips = await TripApi.getTrips();
    final now = DateTime.now();
    final active = activeTrips(trips, now);
    final todos = <Todo>[];
    for (final t in active) {
      todos.addAll(await TripApi.getTripTodos(t.id));
    }
    final result = geofencesForActiveTrips(trips, todos, now);
    await NativeGeofenceManager.instance.initialize();
    await NativeGeofenceManager.instance.removeAllGeofences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNamesKey, jsonEncode(result.names));
    for (final f in result.fences) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: f.id,
          location: Location(latitude: f.lat, longitude: f.lon),
          radiusMeters: _kRadiusMeters,
          // dwell is Android-only; enter is included so iOS does not throw
          // (iOS silently gets enter-based triggers; callback filters for dwell
          //  so iOS users will not receive notifications — see Task 7 notes).
          triggers: const {GeofenceEvent.enter, GeofenceEvent.dwell},
          iosSettings: const IosGeofenceSettings(initialTrigger: false),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {},
            loiteringDelay: _kLoiteringDelay,
          ),
        ),
        nearbyGeofenceCallback,
      );
    }
  } catch (_) {
    // 등록 실패는 무시(권한 미승격·네트워크 등)
  }
}

Future<void> clearGeofences() async {
  if (kIsWeb) return;
  try {
    await NativeGeofenceManager.instance.initialize();
    await NativeGeofenceManager.instance.removeAllGeofences();
  } catch (_) {}
}

/// 별도 isolate에서 실행 — 앱 상태 접근 불가. SharedPreferences만 사용.
@pragma('vm:entry-point')
Future<void> nearbyGeofenceCallback(GeofenceCallbackParams params) async {
  if (params.event != GeofenceEvent.dwell) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final names = (jsonDecode(prefs.getString(_kNamesKey) ?? '{}') as Map)
      .cast<String, String>();
  final now = DateTime.now();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      '근처 장소',
      channelDescription: '저장한 여행 장소 근처 알림',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  for (final g in params.geofences) {
    final id = g.id;
    final lastMs = prefs.getInt('$_kLastPrefix$id');
    final lastAt =
        lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (!shouldNotify(lastAt, now, _kCooldown)) continue;
    final name = names[id] ?? '저장한 장소';
    // 알림 ID: due-reminder 범위 [0, 1.9e9) 및 morningId(1999999999)와 충돌 방지를
    // 위해 지오펜스 알림은 2_000_000_000 이상 범위를 사용.
    final notifId = 2000000000 + (id.hashCode & 0x7fffffff) % 100000000;
    await plugin.show(notifId, '계획한 $name 근처예요',
        '가는 김에 들러볼까요?', details);
    await prefs.setInt('$_kLastPrefix$id', now.millisecondsSinceEpoch);
  }
}
