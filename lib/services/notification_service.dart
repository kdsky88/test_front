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
      if (t.completed) continue;
      final fireAt = fireTimeFor(t.dueAt, lead, now);
      if (fireAt == null) continue;
      final when = tz.TZDateTime.from(fireAt, tz.local);
      try {
        await _scheduleAt(
          _idFor(t.id),
          '마감: ${t.title}',
          t.note ?? '지금 마감이에요.',
          when,
        );
      } catch (_) {
        // 한 건 예약 실패가 나머지 항목·아침 요약 예약까지 막지 않도록 무시
      }
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
    try {
      await _scheduleAt(
        _morningId,
        '오늘 할 일 $count개',
        '오늘 처리할 일이 $count개 있어요.',
        when,
      );
    } catch (_) {}
  }

  /// 정확 알람으로 예약, 불가하면 부정확(늦더라도 오는 게 안 오는 것보다 나음)으로 폴백.
  /// 성공 시 사용한 모드('exact'/'inexact') 반환. 둘 다 실패하면 예외 전파.
  static Future<String> _scheduleAt(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id, title, body, when, _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return 'exact';
    } catch (_) {
      await _plugin.zonedSchedule(
        id, title, body, when, _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return 'inexact';
    }
  }

  /// 마감 알림 발사 시각(순수, 테스트용). null이면 예약 안 함(마감 없음/이미 지남).
  /// lead가 마감을 과거로 밀면 마감 시각으로 클램프 — 이미 lead 창 안이면 최소 마감 때라도 알림.
  static DateTime? fireTimeFor(DateTime? due, Duration lead, DateTime now) {
    if (due == null || !due.isAfter(now)) return null;
    final fireAt = due.subtract(lead);
    return fireAt.isBefore(now) ? due : fireAt;
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

  /// 즉시 테스트 알림. 권한을 (재)요청하고 바로 하나 띄움.
  /// 반환: 알림 권한 허용 여부(false면 시스템 설정에서 켜야 함).
  static Future<bool> sendTest() async {
    if (!_ready) await init();
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin.show(_testId, '테스트 알림', '알림이 정상 작동해요 ✅', _details);
    return granted ?? true;
  }

  /// 알림 진단: 권한/정확알람 가능 여부를 읽고, 실제 예약 경로로 2분 뒤 테스트를
  /// 예약한 뒤 '진짜로 예약됐는지'(pendingNotificationRequests)를 되읽어 리포트.
  /// → 예약 자체 실패(코드/권한) vs 예약은 됐는데 안 울림(배터리/OEM)을 가른다.
  /// 절대 예외를 던지지 않고 항상 리포트 문자열을 반환(호출 하나가 실패해도 UI가 뜨도록).
  static Future<String> diagnostics() async {
    final lines = <String>[];
    try {
      if (!_ready) await init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      try {
        await android?.requestNotificationsPermission();
      } catch (_) {}
      bool? enabled;
      try {
        enabled = await android?.areNotificationsEnabled();
      } catch (e) {
        lines.add('알림 켜짐 확인 오류: $e');
      }
      bool? canExact;
      try {
        canExact = await android?.canScheduleExactNotifications();
      } catch (e) {
        lines.add('정확 알람 확인 오류: $e');
      }
      lines.add('알림 켜짐: ${_yn(enabled)}');
      lines.add('정확 알람 가능: ${_yn(canExact)}');
      final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
      try {
        final mode = await _scheduleAt(
            _testScheduledId, '예약 테스트', '2분 뒤 예약 알림 도착 ✅', when);
        lines.add('2분 뒤 예약: $mode 모드로 성공');
      } catch (e) {
        lines.add('2분 뒤 예약: 실패 — $e');
      }
      try {
        final pending = await _plugin.pendingNotificationRequests();
        lines.add('현재 예약된 알림: ${pending.length}건');
      } catch (e) {
        lines.add('예약 목록 확인 오류: $e');
      }
    } catch (e) {
      lines.add('진단 오류: $e');
    }
    return lines.join('\n');
  }

  static String _yn(bool? b) => b == null ? '?' : (b ? '예' : '아니오');

  static const int _testId = 1999999998; // 즉시 테스트
  static const int _testScheduledId = 1999999997; // 2분 뒤 예약 테스트

  // 아침 요약용 고정 예약 id. todo id 범위(_idFor)와 겹치지 않게 예약.
  static const int _morningId = 1999999999;

  // todo id(문자열)를 알림 id로. _morningId와 충돌 방지 위해 그 아래 범위로 매핑.
  static int _idFor(String todoId) => (todoId.hashCode & 0x7fffffff) % 1900000000;
}
