import 'package:flutter/material.dart';
import '../services/local_auth_prefs.dart';
import '../theme.dart';

/// 생체 잠금 화면: 진입 시 생체 인증을 요구하고, 성공하면 onUnlock. 실패/취소 시 재시도 또는 로그아웃.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock, required this.onLogout});

  final VoidCallback onUnlock;
  final VoidCallback onLogout;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth());
  }

  Future<void> _auth() async {
    final ok = await LocalAuthPrefs.authenticate('잠금 해제');
    if (!mounted) return;
    if (ok) {
      widget.onUnlock();
    } else {
      setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text('잠겨 있어요',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('생체 인증으로 잠금을 해제하세요',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.seed,
              ),
              onPressed: _auth,
              icon: const Icon(Icons.fingerprint),
              label: Text(_tried ? '다시 시도' : '잠금 해제'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onLogout,
              child: const Text('다른 계정으로 로그인', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
