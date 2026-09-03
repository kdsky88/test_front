import 'package:flutter/material.dart';
import '../services/auth_api.dart';

/// 메일 링크(?reset=토큰)로 진입하는 새 비밀번호 설정 화면.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token, required this.onDone});

  final String token;

  /// 완료(또는 취소) 시: 앱을 로그인 화면으로 되돌리게 한다.
  final VoidCallback onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthApi.resetPassword(token: widget.token, newPassword: _pw1.text);
      if (mounted) setState(() => _done = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '서버에 연결할 수 없습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 재설정')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _done ? _success(scheme) : _form(scheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(ColorScheme scheme) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          const Text('비밀번호가 변경됐어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('새 비밀번호로 로그인하세요.'),
          const SizedBox(height: 24),
          FilledButton(onPressed: widget.onDone, child: const Text('로그인하러 가기')),
        ],
      );

  Widget _form(ColorScheme scheme) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_reset, size: 56, color: scheme.primary),
            const SizedBox(height: 24),
            TextFormField(
              controller: _pw1,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '새 비밀번호 (8자 이상)', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.length < 8) ? '8자 이상 입력해주세요.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw2,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: '새 비밀번호 확인', border: OutlineInputBorder()),
              validator: (v) => (v != _pw1.text) ? '비밀번호가 일치하지 않아요.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('비밀번호 변경'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: widget.onDone, child: const Text('취소')),
          ],
        ),
      );
}
