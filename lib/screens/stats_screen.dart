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
      // 완료 시각 내림차순 전용 엔드포인트라 '오늘 완료' 수치와 기록 상단이 어긋나지 않음.
      final res = await TodoApi.getCompletedHistory(page: 1, limit: 100);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _completed = res.data;
        _truncated = res.total > res.data.length;
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
      if (s.streakDays > 0 || s.longestStreak > 0) ...[
        const SizedBox(height: 12),
        _streakBanner(context, s.streakDays, s.longestStreak),
      ],
      const SizedBox(height: 16),
      _weeklyChart(context, s.last7Days),
      const SizedBox(height: 16),
      Row(
        children: [
          _statTile(context, '오늘', '${s.completedToday}', Icons.today,
              theme.colorScheme.primary),
          const SizedBox(width: 10),
          _statTile(context, '이번 주', '${s.completedThisWeek}',
              Icons.date_range, Colors.green.shade600),
          const SizedBox(width: 10),
          _statTile(context, '이번 달', '${s.completedThisMonth}',
              Icons.calendar_month, Colors.indigo.shade400),
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
          Text(
            '전체 ${s.total}개 중 ${s.completed}개 완료 · 미완료 ${s.active}개'
            '${s.overdue > 0 ? ' (지연 ${s.overdue})' : ''}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _streakBanner(BuildContext context, int days, int longest) {
    final theme = Theme.of(context);
    final active = days > 0;
    final color = active
        ? Colors.deepOrange.shade400
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: active
            ? Colors.deepOrange.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? Colors.deepOrange.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.local_fire_department : Icons.ac_unit,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: active
                    ? [
                        TextSpan(
                          text: '$days일 연속',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade700,
                          ),
                        ),
                        TextSpan(
                          text: ' 완료 중이에요!',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ]
                    : [
                        TextSpan(
                          text: '연속 기록이 끊겼어요',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
              ),
            ),
          ),
          Text('최고 $longest일',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }

  Widget _weeklyChart(BuildContext context, List<int> counts) {
    final theme = Theme.of(context);
    if (counts.length != 7) return const SizedBox.shrink();
    final maxVal = counts.fold<int>(0, (m, c) => c > m ? c : m);
    const weekdayKo = ['일', '월', '화', '수', '목', '금', '토'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주간 완료 추이',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final date = today.subtract(Duration(days: 6 - i));
                final count = counts[i];
                final isToday = i == 6;
                final frac = maxVal == 0 ? 0.0 : count / maxVal;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(count > 0 ? '$count' : '',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6 + frac * 66,
                        decoration: BoxDecoration(
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(weekdayKo[date.weekday % 7],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isToday ? FontWeight.bold : null,
                          )),
                    ],
                  ),
                );
              }),
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
    // 라벨별 개수(정렬돼 있어 같은 날짜가 연속).
    final counts = <String, int>{};
    for (final t in _completed) {
      final label = _dateLabel(t.completedAt);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final widgets = <Widget>[];
    String? lastLabel;
    for (final t in _completed) {
      final label = _dateLabel(t.completedAt);
      if (label != lastLabel) {
        lastLabel = label;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text('$label · ${counts[label]}개',
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
    final prColor = switch (t.priority) {
      TodoPriority.high => Colors.red.shade400,
      TodoPriority.medium => Colors.orange.shade500,
      TodoPriority.low => Colors.blue.shade400,
    };
    // 마감 대비 제때/지연 완료
    final onTime = (t.dueAt != null && t.completedAt != null)
        ? !t.completedAt!.isAfter(t.dueAt!)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: prColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(t.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75))),
                    ),
                    if (onTime != null) ...[
                      const SizedBox(width: 6),
                      _onTimeBadge(context, onTime),
                    ],
                  ],
                ),
                if (t.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: t.tags
                          .map((tag) => Text('#$tag',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.8))))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(time,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _onTimeBadge(BuildContext context, bool onTime) {
    final color =
        onTime ? Colors.green.shade600 : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(onTime ? '제때' : '지연',
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
