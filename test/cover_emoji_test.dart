import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/widgets/cover_image.dart';

void main() {
  test('지명에 맞는 이모지', () {
    expect(coverEmoji('제주'), '🏝️');
    expect(coverEmoji('삿포로'), '❄️');
    expect(coverEmoji('도쿄'), '🏙️');
    expect(coverEmoji('파리'), '🗼');
    expect(coverEmoji('설악산'), '🏔️');
    expect(coverEmoji('벳푸 온천'), '♨️');
  });

  // '산' 한 글자 키를 두면 부산·울산·군산이 전부 산이 된다(회귀 방어).
  test('바다 도시가 산으로 잡히지 않는다', () {
    expect(coverEmoji('부산'), '🌊');
    expect(coverEmoji('울산'), '✈️');
    expect(coverEmoji('군산'), '✈️');
  });

  test('모르는 곳·미정은 비행기', () {
    expect(coverEmoji('아무데나'), '✈️');
    expect(coverEmoji(null), '✈️');
    expect(coverEmoji('   '), '✈️');
  });

  test('긴 목적지 문자열에도 붙는다', () {
    expect(coverEmoji('홋카이도 삿포로시'), '❄️');
    expect(coverEmoji('일본 후쿠오카'), '🏙️');
  });
}
