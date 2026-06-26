import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/todo_list_screen.dart';
import 'screens/calendar_screen.dart';
import 'state/todo_notifier.dart';
import 'state/calendar_notifier.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final _todoNotifier = TodoNotifier();
  final _calendarNotifier = CalendarNotifier();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // After a change in one view is persisted, immediately refresh the other
    // (silently) so it's already up to date regardless of when — or how fast —
    // the user switches tabs. The tab-switch refresh below is a backup.
    _todoNotifier.onMutated = () =>
        _calendarNotifier.loadCalendar(silent: true);
    _calendarNotifier.onMutated = () => _todoNotifier.loadTodos(silent: true);
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
    // Both views are independent caches, so refresh the one being shown to
    // reflect changes (edit, complete, delete) made on the other tab. The
    // reload is silent: existing content stays on screen until fresh data
    // arrives. Tab 0 = 달력, tab 1 = 목록.
    if (index == 0) {
      _calendarNotifier.loadCalendar(silent: true);
    } else {
      _todoNotifier.loadTodos(silent: true);
    }
  }

  @override
  void dispose() {
    _todoNotifier.dispose();
    _calendarNotifier.dispose();
    super.dispose();
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      home: Scaffold(
        body: IndexedStack(
          index: _selectedTab,
          children: [
            CalendarScreen(
              calendarNotifier: _calendarNotifier,
              todoNotifier: _todoNotifier,
            ),
            TodoListScreen(notifier: _todoNotifier),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: _onTabSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: '달력',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: '목록',
            ),
          ],
        ),
      ),
    );
  }
}
