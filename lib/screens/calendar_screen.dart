import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../state/calendar_notifier.dart';
import '../state/todo_notifier.dart';
import '../widgets/todo_form_dialog.dart';
import '../widgets/delete_dialog.dart';
import '../widgets/priority_badge.dart';

class CalendarScreen extends StatefulWidget {
  final CalendarNotifier calendarNotifier;
  final TodoNotifier todoNotifier;

  const CalendarScreen({
    super.key,
    required this.calendarNotifier,
    required this.todoNotifier,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.calendarNotifier.loadCalendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.calendarNotifier,
      builder: (context, _) {
        final n = widget.calendarNotifier;
        return Scaffold(
          appBar: AppBar(title: const Text('달력'), centerTitle: false),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            label: const Text('새 Todo'),
          ),
          body: Column(
            children: [
              _buildMonthHeader(context, n),
              if (n.status == CalendarStatus.loading)
                const LinearProgressIndicator()
              else if (n.status == CalendarStatus.error)
                _buildCalendarError(context, n)
              else
                _buildCalendarGrid(context, n),
              const Divider(height: 1),
              _buildSelectedDateLabel(context, n),
              Expanded(child: _buildTodoList(context, n)),
            ],
          ),
        );
      },
    );
  }

  // ─── Month header ──────────────────────────────────────────────

  Widget _buildMonthHeader(BuildContext context, CalendarNotifier n) {
    final loading = n.status == CalendarStatus.loading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: '이전 달',
            onPressed: loading ? null : () => n.prevMonth(),
          ),
          Expanded(
            child: Text(
              '${n.year}년 ${n.month}월',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음 달',
            onPressed: loading ? null : () => n.nextMonth(),
          ),
        ],
      ),
    );
  }

  // ─── Calendar grid ─────────────────────────────────────────────

  Widget _buildCalendarError(BuildContext context, CalendarNotifier n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              n.error ?? '오류가 발생했습니다.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => n.loadCalendar(),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, CalendarNotifier n) {
    final firstDay = DateTime(n.year, n.month, 1);
    final daysInMonth = DateTime(n.year, n.month + 1, 0).day;
    final offset = firstDay.weekday % 7; // Sunday = 0 (week starts on Sunday)

    final cells = <int>[
      ...List.filled(offset, 0),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(0);
    }

    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: weekdays
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < cells.length ~/ 7; row++)
            Row(
              children: [
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: _buildDayCell(context, n, cells[row * 7 + col]),
                  ),
              ],
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, CalendarNotifier n, int day) {
    if (day == 0) return const SizedBox(height: 48);

    final date = DateTime(n.year, n.month, day);
    final isSelected =
        n.selectedDate.year == n.year &&
        n.selectedDate.month == n.month &&
        n.selectedDate.day == day;
    final now = DateTime.now();
    final isToday =
        now.year == n.year && now.month == n.month && now.day == day;
    final hasTodos = n.hasTodos(date);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => n.selectDate(date),
      child: SizedBox(
        height: 48,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : null,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isToday ? theme.colorScheme.primary : null),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              hasTodos
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white70
                            : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Selected date label ───────────────────────────────────────

  Widget _buildSelectedDateLabel(BuildContext context, CalendarNotifier n) {
    final d = n.selectedDate;
    final label = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(d);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Text(
            '${(widget.calendarNotifier.selectedDateTodos.length)}개',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ─── Todo list ─────────────────────────────────────────────────

  Widget _buildTodoList(BuildContext context, CalendarNotifier n) {
    final todos = n.selectedDateTodos;
    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '등록된 할 일이 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add),
              label: const Text('할 일 추가'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      itemCount: todos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) => _buildTodoItem(context, todos[index], n),
    );
  }

  Widget _buildTodoItem(BuildContext context, Todo todo, CalendarNotifier n) {
    final theme = Theme.of(context);
    final isProcessing = n.isProcessing(todo.id);
    final itemError = n.itemError(todo.id);
    final overdue = todo.isOverdue;
    final dueSoon = todo.isDueSoon;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: todo.completed
          ? theme.colorScheme.surfaceContainerLow
          : (overdue
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
                : (dueSoon
                      ? Colors.orange.withValues(alpha: 0.08)
                      : theme.colorScheme.surface)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(2),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Checkbox(
                          value: todo.completed,
                          onChanged: (_) => n.toggleComplete(todo.id),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PriorityBadge(priority: todo.priority),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              todo.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: todo.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.completed
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : null,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (todo.completed)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '완료',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (todo.note != null && todo.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            todo.note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: todo.completed ? 0.5 : 1.0),
                              decoration: todo.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (todo.startAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '시작 ${DateFormat('yyyy-MM-dd HH:mm').format(todo.startAt!.toLocal())}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (todo.dueAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              overdue
                                  ? Icons.alarm_off
                                  : (dueSoon
                                        ? Icons.alarm
                                        : Icons.schedule),
                              size: 14,
                              color: overdue
                                  ? theme.colorScheme.error
                                  : (dueSoon
                                        ? Colors.orange.shade700
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm').format(todo.dueAt!.toLocal()),
                              style: TextStyle(
                                fontSize: 12,
                                color: overdue
                                    ? theme.colorScheme.error
                                    : (dueSoon
                                          ? Colors.orange.shade700
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5)),
                                fontWeight: (overdue || dueSoon)
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                            if (overdue) ...[
                              const SizedBox(width: 4),
                              Text(
                                '기한 경과',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else if (dueSoon) ...[
                              const SizedBox(width: 4),
                              Text(
                                '임박',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '수정',
                      onPressed: isProcessing
                          ? null
                          : () => _openEdit(context, todo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: '삭제',
                      onPressed: isProcessing
                          ? null
                          : () => _confirmDelete(context, todo),
                    ),
                  ],
                ),
              ],
            ),
            if (itemError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 34),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        itemError,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => n.clearItemError(todo.id),
                      child: const Text('닫기', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────

  void _openCreate(BuildContext context) async {
    final selected = widget.calendarNotifier.selectedDate;
    // KST midnight for the selected date: local midnight, form converts to UTC Z
    final initialDueAt = DateTime(selected.year, selected.month, selected.day);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoFormDialog(
        notifier: widget.todoNotifier,
        initialDueAt: initialDueAt,
      ),
    );
    if (result == true && mounted) {
      widget.calendarNotifier.loadCalendar();
    }
  }

  void _openEdit(BuildContext context, Todo todo) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoFormDialog(todo: todo, notifier: widget.todoNotifier),
    );
    if (result == true && mounted) {
      widget.calendarNotifier.loadCalendar();
    }
  }

  void _confirmDelete(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (_) => DeleteDialog(
        todoTitle: todo.title,
        onDelete: () => widget.calendarNotifier.deleteTodo(todo.id),
      ),
    );
  }
}
