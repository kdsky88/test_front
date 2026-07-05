import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/todo_api.dart';

/// 완료 통계 + 최근 완료 기록. 통계 수치는 서버 집계(정확), 기록 목록은 최근 100개.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  TodoStats? _stats;
  List<Todo> _completed = [];
  bool _loading = true;
  bool _error = false;
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final stats = await TodoApi.getStats();
      final res = await TodoApi.getTodos(
        status: 'completed',
        page: 1,
        limit: 100,
        sort: 'createdAt',
      );
      final completed = List<Todo>.of(res.data)..sort(_byCompletedDesc);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _completed = completed;
        _truncated = res.total > completed.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  int _byCompletedDesc(Todo a, Todo b) {
    final ac = a.completedAt, bc = b.completedAt;
    if (ac == null && bc == null) return 0;
    if (ac == null) return 1;
    if (bc == null) return -1;
    return bc.compareTo(ac); // 최근 완료가 위로
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('완료 통계')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
            ? _errorView(context)
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: _content(context),
              ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('통계를 불러오지 못했어요.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final theme = Theme.of(context);
    final s = _stats!;
    return [
      _completionCard(context, s),
      if (s.streakDays > 0) ...[
        const SizedBox(height: 12),
        _streakBanner(context, s.streakDays),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          _statTile(context, '오늘 완료', '${s.completedToday}', Icons.today,
              theme.colorScheme.primary),
          const SizedBox(width: 10),
          _statTile(context, '이번 주 완료', '${s.completedThisWeek}',
              Icons.date_range, Colors.green.shade600),
          const SizedBox(width: 10),
          _statTile(context, '지연', '${s.overdue}', Icons.alarm_off,
              theme.colorScheme.error),
        ],
      ),
      const SizedBox(height: 24),
      Text('완료 기록',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      if (_truncated)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('최근 100개만 표시',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      const SizedBox(height: 8),
      if (_completed.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('아직 완료한 할 일이 없어요.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
        )
      else
        ..._historyList(context),
    ];
  }

  Widget _completionCard(BuildContext context, TodoStats s) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s.completionPercent}%',
                  style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('완료율',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.total == 0 ? 0 : s.completed / s.total,
              minHeight: 10,
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 10),
          Text('전체 ${s.total}개 중 ${s.completed}개 완료 · 미완료 ${s.active}개',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _streakBanner(BuildContext context, int days) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: Colors.deepOrange.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$days일 연속',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                  TextSpan(
                    text: ' 완료 중이에요!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  List<Widget> _historyList(BuildContext context) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    String? lastLabel;
    for (final t in _completed) {
      final label = _dateLabel(t.completedAt);
      if (label != lastLabel) {
        lastLabel = label;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(label,
              style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant)),
        ));
      }
      widgets.add(_historyRow(context, t));
    }
    return widgets;
  }

  Widget _historyRow(BuildContext context, Todo t) {
    final theme = Theme.of(context);
    final time = t.completedAt == null
        ? ''
        : DateFormat('HH:mm').format(t.completedAt!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle,
              size: 18, color: Colors.green.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.7))),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(time,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime? completedAt) {
    if (completedAt == null) return '완료 시각 미기록';
    final d = completedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return DateFormat('M월 d일').format(day);
  }
}
