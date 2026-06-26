import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../state/todo_notifier.dart';
import 'todo_form_dialog.dart';
import 'priority_badge.dart';

class TodoItemWidget extends StatelessWidget {
  final Todo todo;
  final TodoNotifier notifier;

  const TodoItemWidget({super.key, required this.todo, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProcessing = notifier.isProcessing(todo.id);
    final itemError = notifier.itemError(todo.id);
    final overdue = todo.isOverdue;
    final dueToday = todo.isDueToday;
    final dueSoon = todo.isDueSoon;
    final dueRed = overdue || dueToday; // 당일/경과 → 빨강, 하루 전 → 주황
    final dueAccent = dueRed
        ? theme.colorScheme.error
        : (dueSoon
              ? Colors.orange.shade500
              : theme.colorScheme.onSurface.withValues(alpha: 0.5));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: dueRed
              ? BorderSide(color: theme.colorScheme.error, width: 1.5)
              : (dueSoon
                    ? BorderSide(color: Colors.orange.shade500, width: 1.5)
                    : BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        color: todo.completed
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            onChanged: (_) => notifier.toggleComplete(todo.id),
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
                                    .withValues(
                                      alpha: todo.completed ? 0.5 : 1.0,
                                    ),
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
                                    : ((dueToday || dueSoon)
                                          ? Icons.alarm
                                          : Icons.schedule),
                                size: 14,
                                color: dueAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '마감 ${DateFormat('yyyy-MM-dd HH:mm').format(todo.dueAt!.toLocal())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dueAccent,
                                  fontWeight: (dueRed || dueSoon)
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
                              ] else if (dueToday) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '오늘 마감',
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
                                    color: Colors.orange.shade500,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (todo.recurrence != TodoRecurrence.none) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                todo.recurrence.shortLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (todo.assignee != null &&
                            todo.assignee!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                todo.assignee!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (todo.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: todo.tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
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
                            : () => _openEdit(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: '삭제',
                        onPressed: isProcessing
                            ? null
                            : () => _confirmDelete(context),
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
                        onPressed: () => notifier.clearItemError(todo.id),
                        child: const Text('닫기', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoFormDialog(todo: todo, notifier: notifier),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = todo;
    final ok = await notifier.deleteTodo(removed.id);
    if (!ok) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text("'${removed.title}' 삭제됨"),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () => notifier.restoreTodo(removed),
        ),
      ),
    );
  }
}
