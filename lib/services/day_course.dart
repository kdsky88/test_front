import 'dart:math';
import '../models/place.dart';

typedef DistanceFn =
    double Function(double lat1, double lng1, double lat2, double lng2);

/// 하루 코스: 무작위 anchor 근처로 관광지/맛집을 아침·점심·저녁에 **슬롯당 2곳씩** 묶는다.
///
/// 근처 후보(최대 4개) 중 무작위로 골라 '다시'가 매번 다른 코스를 내도록 한다.
/// (거리 계산은 주입 — 테스트에서 플랫폼 의존 없이 검증하려고.)
List<(String, Place)> buildDayCourse(
  List<Place> attractions,
  List<Place> foods, {
  required DistanceFn distance,
  required Random rng,
}) {
  final stops = <(String, Place)>[];
  if (attractions.isEmpty && foods.isEmpty) return stops;
  final anchor = attractions.isNotEmpty
      ? attractions[rng.nextInt(attractions.length)]
      : foods[rng.nextInt(foods.length)];
  double dist(Place p) =>
      distance(anchor.latitude, anchor.longitude, p.latitude, p.longitude);
  final nearA = [...attractions]..sort((a, b) => dist(a).compareTo(dist(b)));
  final nearF = [...foods]..sort((a, b) => dist(a).compareTo(dist(b)));
  final used = <String>{};
  String key(Place p) => p.fsqId ?? p.name;
  // 가장 가까운 것만 고정하면 '다시'가 매번 같아짐 → 근처 후보 중 무작위.
  Place? pickNear(List<Place> sorted) {
    final cands = sorted.where((p) => !used.contains(key(p))).take(4).toList();
    if (cands.isEmpty) return null;
    return cands[rng.nextInt(cands.length)];
  }

  void add(String slot, Place? p) {
    if (p != null && used.add(key(p))) stops.add((slot, p));
  }

  // 한쪽이 모자라면 다른 쪽에서 채운다. 목적지가 특정 장소면(예: '삿포로 TV 타워')
  // 관광지가 한두 곳밖에 안 잡혀 슬롯이 비던 걸 막는다.
  Place? pick(List<Place> first, List<Place> second) =>
      pickNear(first) ?? pickNear(second);

  // 아침=관광지, 점심·저녁=맛집.
  add('아침', anchor);
  add('아침', pick(nearA, nearF));
  add('점심', pick(nearF, nearA));
  add('점심', pick(nearF, nearA));
  add('저녁', pick(nearF, nearA));
  add('저녁', pick(nearF, nearA));
  return stops;
}
