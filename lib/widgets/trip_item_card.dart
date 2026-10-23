import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../theme.dart';

final _timeFmt = DateFormat('HH:mm');

/// 여행 상세의 일정 한 줄: 방문 체크 · 시간 · 제목/장소 · 메뉴. 왼쪽으로 밀면 삭제.
class TripItemCard extends StatelessWidget {
  const TripItemCard({
    super.key,
    required this.todo,
    required this.offline,
    required this.onTap,
    required this.onToggleVisited,
    required this.onEdit,
    required this.onDelete,
  });

  final Todo todo;
  final bool offline;
  final VoidCallback onTap;
  final VoidCallback onToggleVisited;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = todo.startAt ?? todo.dueAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Dismissible(
        key: ValueKey(todo.id),
        direction: offline ? DismissDirection.none : DismissDirection.endToStart,
        background: _swipeDeleteBg(theme),
        // 확인 없이 바로 삭제 → onDelete가 즉시 목록에서 제거(트리 일관성 유지) + 실행취소 스낵바.
        onDismissed: (_) => onDelete(),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 방문 체크(완료 토글)
                  IconButton(
                    icon: Icon(
                      todo.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: todo.completed ? theme.colorScheme.secondary : theme.colorScheme.outline,
                      size: 22,
                    ),
                    tooltip: todo.completed ? '방문 취소' : '방문 체크',
                    visualDensity: VisualDensity.compact,
                    onPressed: offline ? null : onToggleVisited,
                  ),
                  // 시간 배지
                  SizedBox(
                    width: 42,
                    child: Text(
                      when != null ? _timeFmt.format(when.toLocal()) : '—',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 34, color: theme.dividerColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: todo.completed ? TextDecoration.lineThrough : null,
                            color: todo.completed ? theme.colorScheme.outline : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (todo.placeName != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  todo.placeName!,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '옵션',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('수정'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('삭제'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 스와이프 삭제 시 뒤로 드러나는 빨간 삭제 배경.
  Widget _swipeDeleteBg(ThemeData theme) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 6),
            Text('삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
