import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/models/trip.dart';
import 'package:test_front/services/trip_schedule.dart';

Todo todo(String id, {DateTime? start, DateTime? due, bool completed = false, String? place}) => Todo(
      id: id,
      title: id,
      completed: completed,
      priority: TodoPriority.medium,
      startAt: start,
      dueAt: due,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      placeName: place,
    );

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  final trip = Trip(
    id: 't',
    title: '부산',
    destination: '부산',
    startDate: DateTime(2026, 5, 1),
    endDate: DateTime(2026, 5, 2),
  );

  test('tripDays covers start..end inclusive, empty when undated', () {
    expect(tripDays(trip), [DateTime(2026, 5, 1), DateTime(2026, 5, 2)]);
    expect(tripDays(const Trip(id: 'x', title: 'x')), isEmpty);
  });

  test('itemsOnDay includes multi-day ranges and sorts by time', () {
    final late = todo('late', start: DateTime(2026, 5, 1, 18));
    final early = todo('early', start: DateTime(2026, 5, 1, 9));
    final span = todo('span', start: DateTime(2026, 4, 30, 12), due: DateTime(2026, 5, 2, 12));
    final undated = todo('undated');
    final items = itemsOnDay([late, early, span, undated], DateTime(2026, 5, 1));
    expect(items.map((t) => t.id), ['span', 'early', 'late']);
    expect(itemsOnDay([span], DateTime(2026, 5, 3)), isEmpty);
  });

  test('share text groups by day and lists leftovers', () {
    final text = buildTripShareText(trip, [
      todo('해운대', start: DateTime(2026, 5, 1, 10), completed: true, place: '해운대해수욕장'),
      todo('짐 싸기'),
    ]);
    expect(text, contains('✈️ 부산 (부산)'));
    expect(text, contains('📅 2026.05.01 ~ 2026.05.02'));
    expect(text, contains('Day 1 · 5/1'));
    expect(text, contains('✅ 10:00 해운대 · 해운대해수욕장'));
    expect(text, contains('Day 2 · 5/2'));
    expect(text, contains('(일정 없음)'));
    expect(text, contains('그 외\n  짐 싸기'));
    expect(text, endsWith('— P의 여행 플래너'));
  });
}
