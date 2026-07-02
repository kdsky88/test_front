import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/notification_prefs.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _leadOptions = {
    0: '마감 시각에',
    30: '30분 전',
    60: '1시간 전',
    1440: '하루 전',
  };

  late int _lead = NotificationPrefs.leadMinutes;
  late bool _morningOn = NotificationPrefs.morningEnabled;
  late TimeOfDay _morningTime = TimeOfDay(
    hour: NotificationPrefs.morningHour,
    minute: NotificationPrefs.morningMinute,
  );

  Future<void> _saveLead(int v) async {
    setState(() => _lead = v);
    await NotificationPrefs.setLeadMinutes(v);
    await NotificationService.sync(); // 즉시 재예약
  }

  Future<void> _saveMorning({bool? enabled, TimeOfDay? time}) async {
    setState(() {
      if (enabled != null) _morningOn = enabled;
      if (time != null) _morningTime = time;
    });
    await NotificationPrefs.setMorning(
      enabled: _morningOn,
      hour: _morningTime.hour,
      minute: _morningTime.minute,
    );
    await NotificationService.sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          _sectionHeader(context, '알림'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('마감 알림 시점'),
            subtitle: Text('마감 ${_leadOptions[_lead]} 알려줘요'),
            trailing: DropdownButton<int>(
              value: _lead,
              underline: const SizedBox.shrink(),
              items: _leadOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) _saveLead(v);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('아침 요약 알림'),
            subtitle: const Text('매일 정해진 시각에 오늘 할 일 개수를 알려줘요'),
            value: _morningOn,
            onChanged: (v) => _saveMorning(enabled: v),
          ),
          if (_morningOn)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('알림 시각'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _morningTime,
                  );
                  if (picked != null) _saveMorning(time: picked);
                },
                child: Text(_morningTime.format(context)),
              ),
            ),
          const Divider(height: 32),
          _sectionHeader(context, '계정'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('내 계정'),
            subtitle: Text(AuthSession.currentEmail ?? '-'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('비밀번호 변경'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPasswordDialog(context),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '알림은 이 기기에 예약돼요. 앱을 한 번 열면 최신 상태로 다시 예약됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openPasswordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _PasswordDialog());
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    if (next.length < 8) {
      setState(() => _error = '새 비밀번호는 8자 이상이어야 해요.');
      return;
    }
    if (next != _confirmCtrl.text) {
      setState(() => _error = '새 비밀번호가 서로 달라요.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthApi.changePassword(currentPassword: current, newPassword: next);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경됐어요.')),
      );
    } on AuthException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _submitting = false;
        _error = '변경에 실패했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentCtrl,
            obscureText: true,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: '현재 비밀번호'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newCtrl,
            obscureText: true,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '새 비밀번호 (8자 이상)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('변경'),
        ),
      ],
    );
  }
}
