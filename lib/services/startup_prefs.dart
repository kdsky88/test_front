import 'package:shared_preferences/shared_preferences.dart';

class StartupPrefs {
  static bool showWelcome = true;
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showWelcome = !(prefs.getBool('welcome_seen') ?? false);
  }

  static Future<void> markSeen() async {
    showWelcome = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_seen', true);
  }
}
