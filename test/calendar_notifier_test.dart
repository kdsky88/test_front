import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/state/calendar_notifier.dart';

void main() {
  test('calendar todos are sorted by priority while preserving tie order', () {
    final todos = [
      _todo('low-1', TodoPriority.low),
      _todo('high-1', TodoPriority.high),
      _todo('medium-1', TodoPriority.medium),
      _todo('high-2', TodoPriority.high),
      _todo('low-2', TodoPriority.low),
    ];

    final sorted = sortCalendarTodosByPriority(todos);

    expect(
      sorted.map((todo) => todo.id),
      ['high-1', 'high-2', 'medium-1', 'low-1', 'low-2'],
    );
  });
}

Todo _todo(String id, TodoPriority priority) {
  final timestamp = DateTime.utc(2026, 6, 13);
  return Todo(
    id: id,
    title: id,
    completed: false,
    priority: priority,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
