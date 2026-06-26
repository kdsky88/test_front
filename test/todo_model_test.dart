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

  group('Todo due urgency (day-based)', () {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    Todo make(DateTime? due, {bool completed = false}) => Todo(
          id: 'x',
          title: 't',
          completed: completed,
          priority: TodoPriority.low,
          dueAt: due,
          createdAt: now,
          updatedAt: now,
        );

    test('overdue when the due time has passed', () {
      final t = make(now.subtract(const Duration(hours: 1)));
      expect(t.isOverdue, isTrue);
      expect(t.isDueToday, isFalse);
      expect(t.isDueSoon, isFalse);
    });

    test('due today (not yet passed) is red but not overdue', () {
      final endOfToday = todayMidnight.add(const Duration(hours: 23, minutes: 59));
      if (!endOfToday.isAfter(now)) return; // skip if run at 23:59
      final t = make(endOfToday);
      expect(t.isOverdue, isFalse);
      expect(t.isDueToday, isTrue);
      expect(t.isDueSoon, isFalse);
    });

    test('due tomorrow is "soon" (orange)', () {
      final t = make(todayMidnight.add(const Duration(days: 1, hours: 9)));
      expect(t.isDueSoon, isTrue);
      expect(t.isDueToday, isFalse);
      expect(t.isOverdue, isFalse);
    });

    test('2+ days away has no urgency', () {
      final t = make(todayMidnight.add(const Duration(days: 3, hours: 9)));
      expect(t.isOverdue, isFalse);
      expect(t.isDueToday, isFalse);
      expect(t.isDueSoon, isFalse);
    });

    test('completed todos never show urgency', () {
      final t = make(now.subtract(const Duration(hours: 1)), completed: true);
      expect(t.isOverdue, isFalse);
      expect(t.isDueToday, isFalse);
      expect(t.isDueSoon, isFalse);
    });
  });
}
