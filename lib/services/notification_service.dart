import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/todo.dart';
import 'notification_prefs.dart';
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
    final lead = Duration(minutes: NotificationPrefs.leadMinutes);
    for (final t in todos) {
      final due = t.dueAt;
      if (t.completed || due == null) continue;
      final fireAt = due.subtract(lead); // 마감 N분 전
      if (!fireAt.isAfter(now)) continue; // (마감-lead)가 이미 지났으면 스킵
      final when = tz.TZDateTime.from(fireAt, tz.local);
      await _plugin.zonedSchedule(
        _idFor(t.id),
        '마감: ${t.title}',
        t.note ?? '지금 마감이에요.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    await _scheduleMorningDigest(todos, now);
  }

  /// 아침 요약: 다음 발생 시각에 '오늘 할 일 N개' 하나. 반복 예약이 아니라
  /// 마감 알림처럼 sync마다 다음 1회를 다시 잡음(앱-열림-기반).
  static Future<void> _scheduleMorningDigest(
    List<Todo> todos,
    DateTime now,
  ) async {
    if (!NotificationPrefs.morningEnabled) return;
    final today = DateTime(now.year, now.month, now.day);
    final count = todos.where((t) {
      if (t.completed || t.dueAt == null) return false;
      final d = t.dueAt!.toLocal();
      return !DateTime(d.year, d.month, d.day).isAfter(today); // 오늘 또는 지난 마감
    }).length;
    if (count == 0) return; // 알릴 게 없으면 예약 안 함
    // ponytail: count는 sync 시점 스냅샷(내일 아침 실제 상태 아님). 앱-열림 모델과 일관.
    final m = nextMorning(now, NotificationPrefs.morningHour,
        NotificationPrefs.morningMinute);
    final when = tz.TZDateTime(tz.local, m.year, m.month, m.day, m.hour, m.minute);
    await _plugin.zonedSchedule(
      _morningId,
      '오늘 할 일 $count개',
      '오늘 처리할 일이 $count개 있어요.',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 다음 아침 알림 시각(로컬 벽시계). 오늘 그 시각이 아직 안 지났으면 오늘, 지났으면 내일.
  /// 순수 함수(테스트용). Asia/Seoul은 DST 없어 벽시계=tz.local.
  static DateTime nextMorning(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      '마감 알림',
      channelDescription: '할 일 마감 시각 알림',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  // 아침 요약용 고정 예약 id. todo id 범위(_idFor)와 겹치지 않게 예약.
  static const int _morningId = 1999999999;

  // todo id(문자열)를 알림 id로. _morningId와 충돌 방지 위해 그 아래 범위로 매핑.
  static int _idFor(String todoId) => (todoId.hashCode & 0x7fffffff) % 1900000000;
}
