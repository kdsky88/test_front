import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import 'screens/todo_list_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/lock_screen.dart';
import 'state/todo_notifier.dart';
import 'state/calendar_notifier.dart';
import 'services/api_config.dart';
import 'services/auth_api.dart';
import 'services/local_auth_prefs.dart';
import 'services/notification_prefs.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  warmBackend(); // 스플래시 동안 Render 백엔드 콜드스타트 예열(fire-and-forget)
  await AuthSession.load(); // 저장된 토큰 복원 후 시작
  await LocalAuthPrefs.load(); // 이메일 기억 + 생체 잠금 설정
  await NotificationPrefs.load(); // 알림 설정(미리 알림·아침 요약)
  await NotificationService.init(); // 마감 알림 채널·권한
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
  bool _showSplash = true; // 시작 시 스플래시 애니메이션
  // 로그인 상태 + 생체 잠금 켜짐이면 잠금 화면 게이트.
  bool _locked = AuthSession.isAuthenticated && LocalAuthPrefs.biometricEnabled;

  @override
  void initState() {
    super.initState();
    // After a change in one view is persisted, immediately refresh the other
    // (silently) so it's already up to date regardless of when — or how fast —
    // the user switches tabs. The tab-switch refresh below is a backup.
    _todoNotifier.onMutated = () {
      _calendarNotifier.loadCalendar(silent: true);
      NotificationService.sync(); // 마감 알림 재예약
    };
    _calendarNotifier.onMutated = () {
      _todoNotifier.loadTodos(silent: true);
      NotificationService.sync();
    };
    // refresh까지 실패(장기 미사용 등)하면 로그인 화면으로 복귀.
    AuthSession.onExpired = () {
      if (mounted && _isAuthenticated) {
        setState(() {
          _isAuthenticated = false;
          _selectedTab = 0;
        });
      }
    };
    // 이미 로그인 상태(토큰 복원)면 알림 예약
    if (_isAuthenticated) NotificationService.sync();
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    HapticFeedback.mediumImpact();
    setState(() => _selectedTab = index);
    // Both views are independent caches, so refresh the one being shown to
    // reflect changes (edit, complete, delete) made on the other tab. The
    // reload is silent: existing content stays on screen until fresh data
    // arrives. Tab 0 = 여행(자체 상태 관리), 1 = 달력, 2 = 할일.
    if (index == 1) {
      _calendarNotifier.loadCalendar(silent: true);
    } else if (index == 2) {
      _todoNotifier.loadTodos(silent: true);
    }
  }

  void _onAuthenticated() {
    setState(() => _isAuthenticated = true);
    _calendarNotifier.loadCalendar();
    _todoNotifier.loadTodos(initial: true);
    _todoNotifier.loadAssignees();
    NotificationService.sync();
  }

  void _logout() {
    AuthSession.clear();
    NotificationService.cancelAll();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P의 여행 플래너',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onDone: () {
                  if (mounted) setState(() => _showSplash = false);
                },
              )
            : KeyedSubtree(key: const ValueKey('home'), child: _home()),
      ),
    );
  }

  Widget _home() {
    if (!_isAuthenticated) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    if (_locked) {
      return LockScreen(
        key: const ValueKey('lock'),
        onUnlock: () => setState(() => _locked = false),
        onLogout: () {
          _logout();
          setState(() => _locked = false);
        },
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          TripsScreen(onLogout: _logout, notifier: _todoNotifier),
          CalendarScreen(
            calendarNotifier: _calendarNotifier,
            todoNotifier: _todoNotifier,
            onLogout: _logout,
          ),
          TodoListScreen(
            notifier: _todoNotifier,
            onLogout: _logout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: '여행',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '달력',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '할 일',
          ),
        ],
      ),
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
  bool _rememberEmail = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = LocalAuthPrefs.rememberedEmail;
    if (saved != null && saved.isNotEmpty) {
      _emailController.text = saved;
    } else {
      _rememberEmail = false;
    }
  }

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
      // 이메일 기억: 로그인 성공 시 체크 상태대로 저장/삭제.
      await LocalAuthPrefs.setRememberedEmail(
          _rememberEmail ? _emailController.text.trim() : null);
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
                    if (!_isRegister)
                      CheckboxListTile(
                        value: _rememberEmail,
                        onChanged: _isSubmitting
                            ? null
                            : (v) => setState(() => _rememberEmail = v ?? false),
                        title: const Text('이메일 기억하기'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
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
