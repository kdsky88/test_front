import 'package:shared_preferences/shared_preferences.dart';

/// 알림 설정(기기 로컬). main()에서 load() 후 NotificationService가 참조.
class NotificationPrefs {
  static int leadMinutes = 0; // 마감 몇 분 전에 알림 (0 = 마감 시각)
  static bool morningEnabled = false;
  static int morningHour = 8;
  static int morningMinute = 0;

  static const _kLead = 'notif_lead_minutes';
  static const _kMorningOn = 'notif_morning_enabled';
  static const _kMorningH = 'notif_morning_hour';
  static const _kMorningM = 'notif_morning_minute';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    leadMinutes = p.getInt(_kLead) ?? 0;
    morningEnabled = p.getBool(_kMorningOn) ?? false;
    morningHour = p.getInt(_kMorningH) ?? 8;
    morningMinute = p.getInt(_kMorningM) ?? 0;
  }

  static Future<void> setLeadMinutes(int v) async {
    leadMinutes = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLead, v);
  }

  static Future<void> setMorning({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    morningEnabled = enabled;
    morningHour = hour;
    morningMinute = minute;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMorningOn, enabled);
    await p.setInt(_kMorningH, hour);
    await p.setInt(_kMorningM, minute);
  }
}
