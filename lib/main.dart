import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/todo_list_screen.dart';
import 'screens/calendar_screen.dart';
import 'state/todo_notifier.dart';
import 'state/calendar_notifier.dart';
import 'services/auth_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.load(); // 저장된 토큰 복원 후 시작
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
  bool _isAuthenticated = AuthSession.isAuthenticated;

  @override
  void initState() {
    super.initState();
    // After a change in one view is persisted, immediately refresh the other
    // (silently) so it's already up to date regardless of when — or how fast —
    // the user switches tabs. The tab-switch refresh below is a backup.
    _todoNotifier.onMutated = () =>
        _calendarNotifier.loadCalendar(silent: true);
    _calendarNotifier.onMutated = () => _todoNotifier.loadTodos(silent: true);
    // refresh까지 실패(장기 미사용 등)하면 로그인 화면으로 복귀.
    AuthSession.onExpired = () {
      if (mounted && _isAuthenticated) {
        setState(() {
          _isAuthenticated = false;
          _selectedTab = 0;
        });
      }
    };
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

  void _onAuthenticated() {
    setState(() => _isAuthenticated = true);
    _calendarNotifier.loadCalendar();
    _todoNotifier.loadTodos(initial: true);
    _todoNotifier.loadAssignees();
  }

  void _logout() {
    AuthSession.clear();
    setState(() {
      _isAuthenticated = false;
      _selectedTab = 0;
    });
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
      home: _isAuthenticated
          ? Scaffold(
              appBar: AppBar(
                title: const Text('할 일'),
                actions: [
                  IconButton(
                    tooltip: '로그아웃',
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
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
            )
          : AuthScreen(onAuthenticated: _onAuthenticated),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegister = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final token = _isRegister
          ? await AuthApi.register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await AuthApi.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      AuthSession.update(token);
      widget.onAuthenticated();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '서버에 연결할 수 없습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? '회원가입' : '로그인')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 28),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? '이름을 입력해주세요.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return '이메일을 입력해주세요.';
                        if (!email.contains('@')) return '이메일 형식을 확인해주세요.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? '비밀번호를 입력해주세요.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isRegister ? Icons.person_add : Icons.login),
                      label: Text(_isRegister ? '가입하기' : '로그인'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              });
                            },
                      child: Text(_isRegister ? '로그인으로 이동' : '회원가입으로 이동'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
