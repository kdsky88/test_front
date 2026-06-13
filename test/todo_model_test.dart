import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/todo.dart';

void main() {
  group('Todo priority parsing', () {
    test('parses supported API values', () {
      expect(TodoPriority.fromJson('HIGH'), TodoPriority.high);
      expect(TodoPriority.fromJson('MEDIUM'), TodoPriority.medium);
      expect(TodoPriority.fromJson('LOW'), TodoPriority.low);
    });

    test('rejects missing and unsupported API values', () {
      expect(() => TodoPriority.fromJson(null), throwsFormatException);
      expect(() => TodoPriority.fromJson('URGENT'), throwsFormatException);
    });

    test('Todo response requires a valid priority', () {
      final json = <String, dynamic>{
        'id': 'todo-1',
        'title': '할 일',
        'description': null,
        'completed': false,
        'priority': 'HIGH',
        'dueAt': null,
        'completedAt': null,
        'createdAt': '2026-06-13T00:00:00.000Z',
        'updatedAt': '2026-06-13T00:00:00.000Z',
      };

      expect(Todo.fromJson(json).priority, TodoPriority.high);
      expect(() => Todo.fromJson({...json, 'priority': 'INVALID'}), throwsFormatException);
    });
  });
}
