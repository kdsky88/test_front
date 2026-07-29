import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../state/todo_notifier.dart';
import 'priority_badge.dart';
import 'todo_form_dialog.dart';

/// 할 일 상세를 바텀시트로 연다. 하위 항목은 여기서 체크한다.
Future<void> showTodoDetail(
  BuildContext context, {
  required Todo todo,
  required TodoNotifier notifier,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TodoDetailSheet(todo: todo, notifier: notifier),
  );
}

class _TodoDetailSheet extends StatefulWidget {
  final Todo todo;
  final TodoNotifier notifier;

  const _TodoDetailSheet({required this.todo, required this.notifier});

  @override
  State<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends State<_TodoDetailSheet> {
  late Todo _todo;
  // 체크 상태의 소스. 낙관적으로 즉시 반영하고, 서버 전송은 아래 체인으로 직렬화.
  late List<Subtask> _subtasks;
  Future<void> _sendChain = Future.value();
  String? _error;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
    _subtasks = List.of(widget.todo.subtasks);
  }

  /// 낙관적으로 즉시 토글하고, 최신 목록 전송을 체인에 이어붙여 순서대로 반영.
  /// 통째로 교체하는 API라 병렬 전송은 서로 덮어쓰므로 직렬화가 필요.
  void _toggleSubtask(int index) {
    setState(() {
      _subtasks[index] = _subtasks[index].copyWith(done: !_subtasks[index].done);
      _error = null;
    });
    _sendChain = _sendChain.then((_) async {
      if (!mounted) return;
      final snapshot = List<Subtask>.of(_subtasks);
      final (updated, err) = await widget.notifier.updateSubtasks(
        _todo.id,
        snapshot,
      );
      if (!mounted) return;
      setState(() {
        if (updated != null) {
          _todo = updated; // 메타 동기화(체크 상태 소스는 _subtasks 유지)
        } else {
          _error = err;
          _subtasks = List.of(_todo.subtasks); // 실패 시 마지막 확정 상태로 복원
        }
      });
    });
  }

  Future<void> _edit() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TodoFormDialog(todo: _todo, notifier: widget.notifier),
    );
    // 저장되면 목록은 이미 갱신됨 — 시트는 오래된 상태이니 닫는다.
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = _todo;
    final ok = await widget.notifier.deleteTodo(removed.id);
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text("'${removed.title}' 삭제됨"),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () => widget.notifier.restoreTodo(removed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todo = _todo;
    final total = _subtasks.length;
    final done = _subtasks.where((s) => s.done).length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      todo.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: todo.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.completed
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: '수정',
                    onPressed: _edit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '삭제',
                    onPressed: _delete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PriorityBadge(priority: todo.priority),
                  if (todo.completed)
                    _pill(theme, '완료', Colors.green),
                  if (todo.recurrence != TodoRecurrence.none)
                    _iconText(
                      theme,
                      Icons.repeat,
                      todo.recurrence.shortLabel,
                      theme.colorScheme.primary,
                    ),
                ],
              ),
              if (todo.note != null && todo.note!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(todo.note!, style: theme.textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: 14),
              if (todo.tripTitle != null)
                _infoRow(theme, Icons.luggage_outlined, '여행', todo.tripTitle!),
              if (todo.startAt != null)
                _infoRow(
                  theme,
                  Icons.play_circle_outline,
                  '시작',
                  DateFormat('yyyy-MM-dd HH:mm').format(todo.startAt!.toLocal()),
                ),
              if (todo.dueAt != null)
                _infoRow(
                  theme,
                  Icons.schedule,
                  '마감',
                  DateFormat('yyyy-MM-dd HH:mm').format(todo.dueAt!.toLocal()),
                ),
              if (todo.assignedToName != null)
                _infoRow(
                  theme,
                  Icons.people_alt_outlined,
                  '담당(공유)',
                  todo.assignedToName!,
                ),
              if (todo.assignee != null && todo.assignee!.isNotEmpty)
                _infoRow(theme, Icons.person_outline, '담당자', todo.assignee!),
              if (todo.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: todo.tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (total > 0) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.checklist,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '체크리스트',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$done/$total',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                ...List.generate(_subtasks.length, (i) {
                  final sub = _subtasks[i];
                  return InkWell(
                    onTap: () => _toggleSubtask(i),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            sub.done
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 22,
                            color: sub.done
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sub.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: sub.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: sub.done
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            '$label  ',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _iconText(ThemeData theme, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _pill(ThemeData theme, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
