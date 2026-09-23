import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/place.dart';
import 'package:test_front/services/day_course.dart';

// 순서만 필요하므로 제곱거리(플랫폼 의존 없는 순수 계산).
double sqDist(double a, double b, double c, double d) {
  final dx = a - c, dy = b - d;
  return dx * dx + dy * dy;
}

Place p(String name, double lat, double lng) =>
    Place(name: name, latitude: lat, longitude: lng);

void main() {
  test('빈 입력이면 빈 코스', () {
    expect(buildDayCourse([], [], distance: sqDist, rng: Random(1)), isEmpty);
  });

  test('관광지+맛집이 충분하면 슬롯당 2곳씩 6곳, 중복 장소 없음', () {
    final attractions = List.generate(6, (i) => p('A$i', i.toDouble(), 0));
    final foods = List.generate(6, (i) => p('F$i', i.toDouble(), 1));
    final course = buildDayCourse(
      attractions,
      foods,
      distance: sqDist,
      rng: Random(3),
    );
    expect(course.length, 6);
    expect(course.map((e) => e.$1).toList(), [
      '아침',
      '아침',
      '점심',
      '점심',
      '저녁',
      '저녁',
    ]);
    expect(
      course.map((e) => e.$2.name).toSet().length,
      6,
      reason: '같은 장소가 두 슬롯에 들어가면 안 됨',
    );
  });

  test('맛집이 2곳뿐이면 채울 수 있는 만큼만(중복 없이)', () {
    final attractions = List.generate(4, (i) => p('A$i', i.toDouble(), 0));
    final foods = List.generate(2, (i) => p('F$i', i.toDouble(), 1));
    final course = buildDayCourse(
      attractions,
      foods,
      distance: sqDist,
      rng: Random(5),
    );
    expect(course.map((e) => e.$2.name).toSet().length, course.length);
    expect(course.where((e) => e.$1 != '아침').length, 2, reason: '맛집은 2곳뿐');
  });

  // 회귀 방어: 예전엔 점심/오후/저녁이 최근접 고정이라 '다시'가 매번 같았음.
  test("'다시'로 여러 번 생성하면 서로 다른 코스가 나온다", () {
    final attractions = List.generate(8, (i) => p('A$i', i.toDouble(), 0));
    final foods = List.generate(8, (i) => p('F$i', i.toDouble(), 1));
    final rng = Random(7);
    final seen = <String>{};
    for (var i = 0; i < 30; i++) {
      final course = buildDayCourse(
        attractions,
        foods,
        distance: sqDist,
        rng: rng,
      );
      seen.add(course.map((e) => e.$2.name).join(','));
    }
    expect(seen.length, greaterThan(1), reason: '근처 후보 중 무작위라 코스가 달라져야 함');
  });

  test('맛집만 있으면 anchor는 맛집, 중복 없음', () {
    final foods = List.generate(3, (i) => p('F$i', i.toDouble(), 0));
    final course = buildDayCourse([], foods, distance: sqDist, rng: Random(2));
    expect(course, isNotEmpty);
    expect(course.map((e) => e.$2.name).toSet().length, course.length);
  });
}
