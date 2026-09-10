import 'package:flutter/material.dart';
import '../state/todo_notifier.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'todo_list_screen.dart';

/// 여행 외 기능 허브: 할 일 목록·통계·설정·로그아웃.
/// 여행앱 피벗으로 최상위 탭에서 내려온 것들을 한 곳에 모음.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.notifier, required this.onLogout});

  final TodoNotifier notifier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _tile(
            context,
            icon: Icons.checklist_outlined,
            title: '할 일 목록',
            subtitle: '여행과 상관없는 할 일까지 한 곳에서',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TodoListScreen(notifier: notifier, onLogout: onLogout),
            )),
          ),
          _tile(
            context,
            icon: Icons.bar_chart_outlined,
            title: '통계',
            subtitle: '완료율·활동 요약',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const StatsScreen(),
            )),
          ),
          _tile(
            context,
            icon: Icons.settings_outlined,
            title: '알림·설정',
            subtitle: '미리 알림, 생체 잠금 등',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            )),
          ),
          const Divider(height: 24, indent: 16, endIndent: 16),
          _tile(
            context,
            icon: Icons.logout,
            title: '로그아웃',
            onTap: onLogout,
            danger: true,
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tint = danger ? scheme.error : scheme.primary;
    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: danger ? scheme.error : scheme.onSurface)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: danger ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
