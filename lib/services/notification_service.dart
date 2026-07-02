import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/todo.dart';
import 'todo_api.dart';

/// 마감 시각에 로컬 알림. 기기 로컬 스케줄이라 서버 푸시 인프라 불필요.
/// ponytail: 타임존은 Asia/Seoul 고정(앱이 KST 기준). 다국가 지원 시 flutter_timezone로 감지.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'due_reminders';

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    // Android 13+ 알림 권한
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// 서버에서 미완료+마감일 있는 항목을 가져와 예약(가장 임박한 100개).
  /// 페이지네이션과 무관하게 다가오는 마감을 폭넓게 커버.
  static Future<void> sync() async {
    if (!_ready) return;
    try {
      final res = await TodoApi.getTodos(
        status: 'active',
        page: 1,
        limit: 100,
        sort: 'dueAt',
      );
      await _reschedule(res.data);
    } catch (_) {
      // 알림 동기화 실패는 조용히 무시(앱 동작 방해 X)
    }
  }

  static Future<void> _reschedule(List<Todo> todos) async {
    await _plugin.cancelAll();
    final now = DateTime.now();
    for (final t in todos) {
      final due = t.dueAt;
      if (t.completed || due == null || !due.toLocal().isAfter(now)) continue;
      final when = tz.TZDateTime.from(due, tz.local);
      await _plugin.zonedSchedule(
        _idFor(t.id),
        '마감: ${t.title}',
        t.note ?? '지금 마감이에요.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '마감 알림',
            channelDescription: '할 일 마감 시각 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  // todo id(문자열)를 32비트 양수 알림 id로.
  static int _idFor(String todoId) => todoId.hashCode & 0x7fffffff;
}
