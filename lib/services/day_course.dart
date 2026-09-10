import 'dart:math';
import '../models/place.dart';

typedef DistanceFn = double Function(
    double lat1, double lng1, double lat2, double lng2);

/// 하루 코스: 무작위 anchor 근처로 관광지/맛집을 오전·점심·오후·저녁에 묶는다.
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

  add('오전', anchor);
  add('점심', pickNear(nearF));
  add('오후', pickNear(nearA));
  add('저녁', pickNear(nearF));
  return stops;
}
