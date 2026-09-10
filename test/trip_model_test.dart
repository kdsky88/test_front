import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/trip.dart';

void main() {
  test('fromJson 파싱', () {
    final t = Trip.fromJson({
      'id': '1',
      'title': '도쿄',
      'destination': '도쿄',
      'startDate': '2026-10-01',
      'endDate': '2026-10-05',
    });
    expect(t.title, '도쿄');
    expect(t.destination, '도쿄');
    expect(t.startDate, DateTime(2026, 10, 1));
    expect(t.endDate, DateTime(2026, 10, 5));
  });

  test('dDayLabel: 시작 전이면 D-n', () {
    final future = DateTime.now().add(const Duration(days: 3));
    final t = Trip(id: '1', title: 'x', startDate: future, endDate: future);
    expect(t.dDayLabel, 'D-3');
  });

  test('dDayLabel: 날짜 없으면 null', () {
    expect(const Trip(id: '1', title: 'x').dDayLabel, isNull);
  });

  test('dDayLabel: 기간 중이면 여행 중', () {
    final now = DateTime.now();
    final t = Trip(
      id: '1',
      title: 'x',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 1)),
    );
    expect(t.dDayLabel, '여행 중');
  });
}
