import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/services/destination_image_api.dart';

void main() {
  // 커버로 못 쓰는 위키 이미지 걸러내기(도시 문서 대표 이미지에 흔한 것들).
  test('몽타주·청사·지도·깃발 이미지는 커버로 쓰지 않는다', () {
    const base = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/b/';
    for (final junk in [
      '${base}Tokyo_Montage_2015.jpg',
      '${base}960px-Gangneung_City_Hall_2.jpg',
      '${base}Flag_of_Jeju.svg.png',
      '${base}Coat_of_arms_of_Paris.svg.png',
      '${base}Busan_locator_map.png',
    ]) {
      expect(isUsableCoverImage(junk), isFalse, reason: junk);
    }
  });

  test('실제 풍경 사진은 통과', () {
    const base = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/b/';
    for (final ok in [
      '${base}960px-Tokyo_Tower_M4854.jpg',
      '${base}960px-Gyeongpo_Lake_20220502_001.jpg',
      '${base}960px-Gamcheon_Colored_Houses.jpg',
      '${base}960px-Fukuoka_Tower.JPG?utm_source=ko.wikipedia.org',
    ]) {
      expect(isUsableCoverImage(ok), isTrue, reason: ok);
    }
  });
}
